// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the food forms: filling a food in from a label, and logging an
/// amount in pieces or grams.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/clock_time.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/food_diary.dart';
import 'package:ippo/modules/food/food_serving.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/food/screens/choose_food_screen.dart';
import 'package:ippo/modules/food/screens/food_entry_form_screen.dart';
import 'package:ippo/modules/food/screens/food_form_screen.dart';
import 'package:ippo/modules/food/screens/label_paste_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  Future<void> setUpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    // Real file access needs runAsync inside widget tests.
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
    });
  }

  testWidgets('a pasted label fills in the form and is saved per 100 g', (
    tester,
  ) async {
    await setUpApp(tester);
    await tester.pumpWidget(
      MaterialApp(home: FoodFormScreen.add(appState: appState)),
    );

    await tester.tap(find.text('Fill in from a label'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(LabelPasteScreen),
        matching: find.byType(TextField),
      ),
      'name: Potato chips\nserving: 9 chips = 28 g\ncalories: 150\n'
      'fat: 9 g\nprotein: 2 g',
    );
    await tester.pump();
    // What was read is shown before filling in.
    expect(find.text('9 chips = 28 g'), findsOneWidget);
    expect(find.text('150 kcal'), findsOneWidget);
    await tester.tap(find.text('Fill in 5 values'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Potato chips'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9 chips'), findsOneWidget);
    expect(find.text('Per serving (28 g)'), findsOneWidget);
    expect(find.text('Filled in 5 values from the label.'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final diary = FoodDiary.fromEvents(appState.eventLog!.events);
    final food = diary.foods.values.single;
    expect(food.name, 'Potato chips');
    expect(food.serving!.describe('g'), '9 chips (28 g)');
    // 150 kcal per 28 g is 535.7 kcal per 100 g.
    expect(food.nutrientsPer100.values, {
      'energy_kcal': 535.7,
      'proteins_g': 7.1,
      'fat_g': 32.1,
    });
  });

  testWidgets('pasted JSON fills in the form, wrapped or not', (tester) async {
    await setUpApp(tester);
    await tester.pumpWidget(
      MaterialApp(home: FoodFormScreen.add(appState: appState)),
    );

    await tester.tap(find.text('Fill in from a label'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(LabelPasteScreen),
        matching: find.byType(TextField),
      ),
      'Here is the label:\n```json\n'
      '{"name": "Rolled oats", "measured_in": "g", "per": "100", '
      '"nutrients": {"energy_kcal": 389, "proteins_g": 13.2, '
      '"protien_g": 1}}\n```',
    );
    await tester.pump();
    expect(find.text('Not used (unknown names): protien_g'), findsOneWidget);
    await tester.tap(find.text('Fill in 3 values'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Rolled oats'), findsOneWidget);
    expect(find.text('Per 100 g'), findsOneWidget);
    expect(find.widgetWithText(TextField, '389'), findsOneWidget);
  });

  testWidgets('+ logs one serving at once, and Undo takes it back', (
    tester,
  ) async {
    await setUpApp(tester);
    await tester.runAsync(() async {
      await FoodActions(appState).createFood(
        name: 'Potato chips',
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 500}),
        serving: const FoodServing(unit: 'chips', count: 9, amount: 28),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ChooseFoodScreen(
                    appState: appState,
                    date: '2026-11-18',
                    isToday: false,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The row shows what one serving comes to.
    expect(find.text('9 chips (28 g) · 140 kcal'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Log 9 chips now'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    var diary = FoodDiary.fromEvents(appState.eventLog!.events);
    final entry = diary.entries.single;
    expect(entry.amount, 28);
    expect(entry.date, '2026-11-18');
    expect(find.text('Logged 9 chips of Potato chips.'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    diary = FoodDiary.fromEvents(appState.eventLog!.events);
    expect(diary.entries.where((entry) => !entry.isDeleted), isEmpty);
  });

  testWidgets('a logged meal can open its food, and take its new values', (
    tester,
  ) async {
    await setUpApp(tester);
    late String foodId;
    await tester.runAsync(() async {
      final actions = FoodActions(appState);
      foodId = (await actions.createFood(
        name: 'Rolled oats',
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 380}),
      )).id;
      final food = FoodDiary.fromEvents(appState.eventLog!.events)
          .foods[foodId]!;
      await actions.recordFoodEntry(
        date: '2026-11-18',
        time: '07:30',
        food: food,
        amount: 50,
      );
    });
    var diary = FoodDiary.fromEvents(appState.eventLog!.events);
    final entry = diary.entries.single;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryFormScreen.edit(appState: appState, entry: entry),
      ),
    );
    // The food can be changed from the meal, at the top and below.
    expect(find.byTooltip('Edit this food'), findsOneWidget);
    expect(find.text('Edit this food'), findsOneWidget);

    // A fixed label value reaches this meal only when asked.
    await tester.runAsync(() async {
      final actions = FoodActions(appState);
      await actions.changeFood(
        foodId,
        nutrientsPer100: const Nutrients({'energy_kcal': 400}),
      );
      final fixed = FoodDiary.fromEvents(appState.eventLog!.events)
          .foods[foodId]!;
      await actions.refreshEntryFromFood(entry, fixed);
    });
    diary = FoodDiary.fromEvents(appState.eventLog!.events);
    expect(diary.entries.single.nutrients.energyKcal, 200);
  });

  testWidgets('an amount can be typed in pieces or grams', (tester) async {
    await setUpApp(tester);
    late String foodId;
    await tester.runAsync(() async {
      final event = await FoodActions(appState).createFood(
        name: 'Potato chips',
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 535.7}),
        serving: const FoodServing(unit: 'chips', count: 9, amount: 28),
      );
      foodId = event.id;
    });
    final food = FoodDiary.fromEvents(appState.eventLog!.events).foods[foodId]!;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryFormScreen.add(
          appState: appState,
          food: food,
          date: '2026-11-18',
          isToday: false,
        ),
      ),
    );

    // Pieces first, because the food has a serving size.
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '9');
    await tester.pump();
    expect(find.textContaining('That is 28 g.'), findsOneWidget);
    expect(find.text('150 kcal'), findsOneWidget);

    // Switching to grams converts what was typed.
    await tester.tap(find.text('g'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '28'), findsOneWidget);
    expect(find.textContaining('That is about 9 chips.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '56');
    await tester.pump();
    expect(find.textContaining('That is about 18 chips.'), findsOneWidget);
  });

  testWidgets('a new entry starts with the amount logged last time', (
    tester,
  ) async {
    await setUpApp(tester);
    late String foodId;
    await tester.runAsync(() async {
      final actions = FoodActions(appState);
      final event = await actions.createFood(
        name: 'Rolled oats',
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 380}),
      );
      foodId = event.id;
      final food = FoodDiary.fromEvents(appState.eventLog!.events)
          .foods[foodId]!;
      await actions.recordFoodEntry(
        date: '2026-11-17',
        time: '07:30',
        food: food,
        amount: 60,
      );
    });
    final food = FoodDiary.of(appState).foods[foodId]!;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryFormScreen.add(
          appState: appState,
          food: food,
          date: '2026-11-18',
          isToday: false,
        ),
      ),
    );

    expect(find.widgetWithText(TextField, '60'), findsOneWidget);
    // Another day: the time is not known, so it starts empty.
    expect(find.text('Not set'), findsOneWidget);
  });

  test('the time a new entry starts with', () {
    expect(
      startingEntryTime(entryTime: '12:15', isNew: false, isToday: false),
      const ClockTime(12, 15),
    );
    expect(
      startingEntryTime(entryTime: null, isNew: true, isToday: false),
      isNull,
    );
    expect(
      startingEntryTime(entryTime: null, isNew: true, isToday: true),
      isNotNull,
    );
  });

  test('changing an entry writes its time only when it changed', () async {
    final folder = Directory.systemTemp.createTempSync('ippo_time_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final state = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await state.load();
    await state.chooseLinuxDataFolder(folder.path);
    final actions = FoodActions(state);
    await actions.recordQuickEntry(
      date: '2026-11-18',
      time: '12:00',
      name: 'Soup',
      nutrients: const Nutrients({'energy_kcal': 300}),
    );
    var entry = FoodDiary.fromEvents(state.eventLog!.events).entries.single;

    final same = await actions.changeQuickEntry(
      entry,
      name: 'Soup',
      nutrients: entry.nutrients,
      date: entry.date,
      time: '12:00',
    );
    expect((same.data['changes']! as Map).containsKey('time'), isFalse);

    await actions.changeQuickEntry(
      entry,
      name: 'Soup',
      nutrients: entry.nutrients,
      date: entry.date,
      time: '13:30',
    );
    entry = FoodDiary.fromEvents(state.eventLog!.events).entries.single;
    expect(entry.time, '13:30');

    // Logged on the wrong day: moved to the day before.
    final dayBefore = formatDate(addDays(parseDate(entry.date)!, -1));
    await actions.changeQuickEntry(
      entry,
      name: 'Soup',
      nutrients: entry.nutrients,
      date: dayBefore,
      time: entry.time,
    );
    final diary = FoodDiary.fromEvents(state.eventLog!.events);
    expect(diary.entriesOn(dayBefore).single.name, 'Soup');
    expect(diary.entriesOn(entry.date), isEmpty);
  });

  testWidgets('both forms fit a narrow phone screen', (tester) async {
    await setUpApp(tester);
    tester.view.physicalSize = const Size(360, 740);
    late String foodId;
    await tester.runAsync(() async {
      final event = await FoodActions(appState).createFood(
        name: 'A rather long name for a bag of salted potato chips',
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 535.7}),
        serving: const FoodServing(unit: 'chips', count: 9, amount: 28),
      );
      foodId = event.id;
    });
    final food = FoodDiary.fromEvents(appState.eventLog!.events).foods[foodId]!;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodFormScreen.edit(appState: appState, food: food),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryFormScreen.add(
          appState: appState,
          food: food,
          date: '2026-11-18',
          isToday: false,
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(home: FoodFormScreen.add(appState: appState)),
    );
    await tester.tap(find.text('Fill in from a label'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Save is in the top bar, and extra nutrients open on demand', (
    tester,
  ) async {
    await setUpApp(tester);
    await tester.pumpWidget(
      MaterialApp(home: FoodFormScreen.add(appState: appState)),
    );

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Save')),
      findsOneWidget,
    );
    expect(find.text('Sugars'), findsNothing);
    await tester.tap(find.text('More nutrients'));
    await tester.pumpAndSettle();
    expect(find.text('Sugars'), findsOneWidget);
  });

  testWidgets('without a serving size, values are per 100 g', (tester) async {
    await setUpApp(tester);
    await tester.pumpWidget(
      MaterialApp(home: FoodFormScreen.add(appState: appState)),
    );
    expect(find.text('Per 100 g'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Oats');
    await tester.enterText(find.widgetWithText(TextField, 'Energy'), '389');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final food = FoodDiary.fromEvents(appState.eventLog!.events)
        .foods
        .values
        .single;
    expect(food.serving, isNull);
    expect(food.nutrientsPer100.energyKcal, 389);
  });
}
