// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the food diary screen shows today's entries and total.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/food/food_actions.dart';
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

  testWidgets('today\'s entries are listed in order, with the total', (
    tester,
  ) async {
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
      final todayText = formatDate(today());
      await actions.recordQuickEntry(
        date: todayText,
        time: null,
        name: 'Porridge',
        nutrients: const Nutrients({'energy_kcal': 300, 'proteins_g': 10}),
      );
      await actions.recordQuickEntry(
        date: todayText,
        time: null,
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
    // One list, no meals; adding is done with the two buttons at the
    // bottom right.
    expect(find.text('Quick food'), findsOneWidget);
    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(find.text('Breakfast'), findsNothing);
    // Each row: the name, "Quick entry" below it, its energy on the right.
    expect(find.text('Quick entry'), findsNWidgets(2));
    expect(find.text('300 kcal'), findsOneWidget);
    expect(find.text('80 kcal'), findsOneWidget);
    // In the order they were logged.
    final porridgeTop = tester.getTopLeft(find.text('Porridge')).dy;
    final appleTop = tester.getTopLeft(find.text('Apple')).dy;
    expect(porridgeTop, lessThan(appleTop));
  });
}
