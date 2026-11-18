// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the food forms: filling a food in from a label, and logging an
/// amount in pieces or grams.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/food_diary.dart';
import 'package:ippo/modules/food/food_serving.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/food/screens/food_entry_form_screen.dart';
import 'package:ippo/modules/food/screens/food_form_screen.dart';
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

    await tester.tap(find.text('Fill in from label'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Label text'),
      'name: Potato chips\nserving: 9 chips = 28 g\ncalories: 150\n'
      'fat: 9 g\nprotein: 2 g',
    );
    await tester.tap(find.text('Fill in'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Potato chips'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'chips'), findsOneWidget);

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
    expect(find.text('= 28 g'), findsOneWidget);
    expect(find.text('150 kcal'), findsOneWidget);

    // Switching to grams converts what was typed.
    await tester.tap(find.text('g'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '28'), findsOneWidget);
    expect(find.text('≈ 9 chips'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '56');
    await tester.pump();
    expect(find.text('≈ 18 chips'), findsOneWidget);
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
    await tester.tap(find.text('Fill in from label'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
