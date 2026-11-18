// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the food diary screen shows today's entries and total.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/food_entry.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/food/screens/food_diary_screen.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('today\'s entries and total are shown by meal', (tester) async {
    // A tall screen, so every meal card is drawn at once.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    // Real file access needs runAsync inside widget tests.
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
      final actions = FoodActions(appState);
      final today = formatDate(DateTime.now());
      await actions.recordQuickEntry(
        date: today,
        time: null,
        meal: Meal.breakfast,
        name: 'Porridge',
        nutrients: const Nutrients({'energy_kcal': 300, 'proteins_g': 10}),
      );
      await actions.recordQuickEntry(
        date: today,
        time: null,
        meal: Meal.snack,
        name: 'Apple',
        nutrients: const Nutrients({'energy_kcal': 80}),
      );
    });

    await tester.pumpWidget(
      MaterialApp(home: FoodDiaryScreen(appState: appState)),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('380 kcal'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('10 g'), findsOneWidget);
    // Every meal has a card with its own Add button; empty ones say so.
    expect(find.text('Add'), findsNWidgets(4));
    expect(find.text('Nothing logged.'), findsNWidgets(2));
    expect(find.text('Breakfast · 300 kcal'), findsOneWidget);
    expect(find.text('Porridge'), findsOneWidget);
    expect(find.text('Snack · 80 kcal'), findsOneWidget);
    expect(find.text('Quick entry · 80 kcal'), findsOneWidget);
  });
}
