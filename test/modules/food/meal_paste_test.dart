// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the "Paste a meal" screen: new foods are added, known ones are
/// reused, and every food is logged with the amount eaten.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/food_diary.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/food/screens/meal_paste_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Four foods as an assistant might send them; the cherries are already
/// in the list (under a name in other capitals).
const String _meal = '''
{
  "time": "12:30",
  "foods": [
    {"name": "Ham", "per": "100", "nutrients": {"energy_kcal": 110, "proteins_g": 21}, "amount": 39},
    {"name": "Cheese", "per": "100", "nutrients": {"energy_kcal": 400, "fat_g": 33}, "amount": 76},
    {"name": "Crackers", "per": "serving",
     "serving": {"unit": "crackers", "count": 27, "amount": 30},
     "nutrients": {"energy_kcal": 150}, "amount": 46},
    {"name": "cherries", "per": "100", "nutrients": {"energy_kcal": 999}, "amount": 86}
  ]
}''';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  testWidgets('a pasted meal adds new foods and logs every amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    final date = formatDate(today());
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
      await FoodActions(appState).createFood(
        name: 'Cherries',
        measuredIn: 'g',
        nutrientsPer100: const Nutrients({'energy_kcal': 63}),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (context) => MealPasteScreen(
                    appState: appState,
                    date: date,
                    isToday: true,
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

    await tester.enterText(find.byType(TextField), _meal);
    await tester.pump();
    expect(find.text('Ham'), findsOneWidget);
    expect(find.textContaining('Already in your foods'), findsOneWidget);
    expect(find.textContaining('New in your foods'), findsNWidgets(3));
    // The known cherries are shown, and logged, with their own 63 kcal
    // per 100 g (54 kcal for 86 g), not the pasted 999.
    expect(find.text('54 kcal'), findsOneWidget);
    expect(find.text('Log 4 foods'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Log 4 foods'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final diary = FoodDiary.of(appState);
    final entries = diary.entriesOn(date);
    expect(entries.map((entry) => entry.name), [
      'Ham',
      'Cheese',
      'Crackers',
      'Cherries',
    ]);
    expect(entries.map((entry) => entry.amount), [39, 76, 46, 86]);
    expect(entries.every((entry) => entry.time == '12:30'), isTrue);
    // Three new foods; the cherries were not added again, and keep their
    // own values.
    expect(diary.foods.values.where((food) => !food.isDeleted), hasLength(4));
    expect(entries.last.nutrients.energyKcal, closeTo(54.2, 0.05));
    // 150 kcal per 30 g serving, 46 g eaten.
    expect(entries[2].nutrients.energyKcal, 230);
  });
}
