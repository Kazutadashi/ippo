// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the food module, from saving events to reading the diary
/// back, with real files in temporary folders.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/food_diary.dart';
import 'package:ippo/modules/food/food_module.dart';
import 'package:ippo/modules/food/nutrients.dart';

const String day = '2026-11-17';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;
  late FoodActions actions;

  FoodDiary currentDiary() => FoodDiary.fromEvents(appState.eventLog!.events);

  /// Reads the diary again from the files on disk, as another device or a
  /// restart would.
  Future<FoodDiary> diaryFromDisk() async {
    await appState.reloadEvents();
    return currentDiary();
  }

  Future<String> createOats() async {
    final event = await actions.createFood(
      name: ' Rolled oats ',
      measuredIn: 'g',
      nutrientsPer100: const Nutrients({
        'energy_kcal': 389,
        'proteins_g': 13.2,
        'fat_g': 6.5,
      }),
    );
    return event.id;
  }

  setUp(() async {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);
    actions = FoodActions(appState);
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  test('a new food is saved with a trimmed name', () async {
    final oatsId = await createOats();

    final oats = (await diaryFromDisk()).foods[oatsId]!;
    expect(oats.name, 'Rolled oats');
    expect(oats.measuredIn, 'g');
    expect(oats.nutrientsPer100.energyKcal, 389);
  });

  test('logging an amount copies the scaled nutrients', () async {
    final oatsId = await createOats();
    await actions.recordFoodEntry(
      date: day,
      time: '07:30',
      food: currentDiary().foods[oatsId]!,
      amount: 60,
    );

    final entry = (await diaryFromDisk()).entriesOn(day).single;
    expect(entry.name, 'Rolled oats');
    expect(entry.amount, 60);
    expect(entry.measuredIn, 'g');
    expect(entry.meal, isNull);
    expect(entry.time, '07:30');
    expect(entry.foodId, oatsId);
    expect(entry.nutrients.values, {
      'energy_kcal': 233.4,
      'proteins_g': 7.9,
      'fat_g': 3.9,
    });
  });

  test('the written line matches the data format', () async {
    final oatsId = await createOats();
    await actions.recordFoodEntry(
      date: day,
      time: null,
      food: currentDiary().foods[oatsId]!,
      amount: 100,
    );

    final file = File(
      '${dataFolder.path}/events/${appState.settings!.deviceId}.jsonl',
    );
    final lastLine = file.readAsLinesSync().last;
    final event = jsonDecode(lastLine) as Map<String, Object?>;
    expect(event['module'], 'food');
    expect(event['type'], 'food_entry_recorded');
    // No time was given, so there is no "time" field; whole numbers are
    // written without ".0".
    expect(event['data'], {
      'date': day,
      'food_id': oatsId,
      'name': 'Rolled oats',
      'amount': 100,
      'measured_in': 'g',
      'nutrients': {'energy_kcal': 389, 'proteins_g': 13.2, 'fat_g': 6.5},
    });
  });

  test('quick entries have no food and no amount', () async {
    await actions.recordQuickEntry(
      date: day,
      time: null,
      name: 'Restaurant lunch',
      nutrients: const Nutrients({'energy_kcal': 850}),
    );

    final entry = (await diaryFromDisk()).entriesOn(day).single;
    expect(entry.isQuickEntry, isTrue);
    expect(entry.foodId, isNull);
    expect(entry.nutrients.energyKcal, 850);
  });

  test('the day total adds up every entry on that day only', () async {
    final oatsId = await createOats();
    final oats = currentDiary().foods[oatsId]!;
    await actions.recordFoodEntry(
      date: day,
      time: null,
      food: oats,
      amount: 50,
    );
    await actions.recordQuickEntry(
      date: day,
      time: null,
      name: 'Apple',
      nutrients: const Nutrients({'energy_kcal': 80}),
    );
    await actions.recordQuickEntry(
      date: '2026-11-18',
      time: null,
      name: 'Other day',
      nutrients: const Nutrients({'energy_kcal': 500}),
    );

    final diary = await diaryFromDisk();
    expect(diary.totalOn(day).energyKcal, 194.5 + 80);
    expect(diary.totalOn('2026-11-18').energyKcal, 500);
    expect(diary.totalOn('2026-11-19').energyKcal, 0);
  });

  test('changing a food does not change past entries', () async {
    final oatsId = await createOats();
    await actions.recordFoodEntry(
      date: day,
      time: null,
      food: currentDiary().foods[oatsId]!,
      amount: 100,
    );

    await actions.changeFood(
      oatsId,
      name: 'Oats (new label)',
      nutrientsPer100: const Nutrients({'energy_kcal': 400}),
    );

    final diary = await diaryFromDisk();
    expect(diary.foods[oatsId]!.name, 'Oats (new label)');
    final entry = diary.entriesOn(day).single;
    expect(entry.name, 'Rolled oats');
    expect(entry.nutrients.energyKcal, 389);
  });

  test('changing an amount scales the entry from its own copy', () async {
    final oatsId = await createOats();
    await actions.recordFoodEntry(
      date: day,
      time: null,
      food: currentDiary().foods[oatsId]!,
      amount: 100,
    );
    // The food changes after logging; the entry must not pick that up.
    await actions.changeFood(
      oatsId,
      nutrientsPer100: const Nutrients({'energy_kcal': 1000}),
    );

    final entry = currentDiary().entriesOn(day).single;
    await actions.changeFoodEntryAmount(entry, newAmount: 50);

    final changed = (await diaryFromDisk()).entriesOn(day).single;
    expect(changed.amount, 50);
    expect(changed.nutrients.energyKcal, 194.5);
    expect(changed.nutrients.values['proteins_g'], 6.6);
  });

  test('deleting and restoring an entry', () async {
    await actions.recordQuickEntry(
      date: day,
      time: null,
      name: 'Apple',
      nutrients: const Nutrients({'energy_kcal': 80}),
    );
    final entry = currentDiary().entriesOn(day).single;

    await actions.deleteEntry(entry.id);
    expect((await diaryFromDisk()).entriesOn(day), isEmpty);

    await actions.restoreEntry(entry.id);
    expect((await diaryFromDisk()).entriesOn(day), hasLength(1));
  });

  test('a deleted food leaves the list but its entries stay', () async {
    final oatsId = await createOats();
    await actions.recordFoodEntry(
      date: day,
      time: null,
      food: currentDiary().foods[oatsId]!,
      amount: 100,
    );

    await actions.deleteFood(oatsId);

    final diary = await diaryFromDisk();
    expect(diary.foodsByRecentUse(), isEmpty);
    expect(diary.entriesOn(day), hasLength(1));
  });

  test('foods are listed most recently used first, then by name', () async {
    Future<String> create(String name) async {
      final event = await actions.createFood(
        name: name,
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 100}),
      );
      return event.id;
    }

    await create('banana');
    final appleId = await create('Apple');
    await create('Cherry');
    final dateId = await create('Date');
    for (final id in [appleId, dateId]) {
      await actions.recordFoodEntry(
        date: day,
        time: null,
        food: currentDiary().foods[id]!,
        amount: 10,
      );
    }

    final names = currentDiary().foodsByRecentUse().map((food) => food.name);
    expect(names, ['Date', 'Apple', 'banana', 'Cherry']);
  });

  test('invalid food data from other tools is counted, not shown', () async {
    await appState.writeEvent(
      module: 'food',
      type: 'food_entry_recorded',
      data: {'date': 'not a date', 'name': 'X', 'nutrients': {}},
    );
    await appState.writeEvent(
      module: 'food',
      type: 'food_created',
      data: {
        'name': 'No unit',
        'nutrients_per_100': {'energy_kcal': 1},
      },
    );

    final diary = await diaryFromDisk();
    expect(diary.invalidCount, 2);
    expect(diary.foods, isEmpty);
    expect(diary.entries, isEmpty);
  });

  test('today\'s facts: eaten, protein, last ate', () async {
    const module = FoodModule();
    final now = DateTime(2026, 11, 17, 15, 30);
    expect(module.todayFacts(appState, now), isEmpty);

    final oatsId = await createOats();
    await actions.recordFoodEntry(
      date: day,
      time: '07:30',
      food: currentDiary().foods[oatsId]!,
      amount: 100,
    );
    await actions.recordQuickEntry(
      date: day,
      time: '12:15',
      name: 'Soup',
      nutrients: const Nutrients({'energy_kcal': 300}),
    );

    final facts = module.todayFacts(appState, now);
    expect(facts.map((fact) => '${fact.label}: ${fact.value}'), [
      'Eaten: 689 kcal',
      'Protein: 13.2 g',
      'Last ate: 3 h 15 min ago',
    ]);
  });
}
