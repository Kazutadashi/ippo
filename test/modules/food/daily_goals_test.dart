// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the daily goals screen, where the calorie limit is set too, and
/// that salt and sodium show as one row in "All nutrients".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/body/body_log.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/food/screens/nutrient_goals_screen.dart';
import 'package:ippo/modules/food/screens/nutrient_summary.dart';
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

  Future<AppState> openGoals(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
    });
    await tester.pumpWidget(
      MaterialApp(home: NutrientGoalsScreen(appState: appState)),
    );
    return appState;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  testWidgets('the calorie limit is set, and removed, with the goals', (
    tester,
  ) async {
    final appState = await openGoals(tester);
    final todayText = formatDate(today());
    expect(find.text('Daily limit, at most'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1800');
    await save(tester);
    expect(BodyLog.of(appState).energyTargetOn(todayText), 1800);

    // Opened again, as the app does: a fresh screen.
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: NutrientGoalsScreen(appState: appState),
      ),
    );
    expect(find.text('1800'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await save(tester);
    expect(BodyLog.of(appState).energyTargetOn(todayText), isNull);
  });

  testWidgets('salt and sodium are one row, salt with its sodium', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AllNutrientsList(
            nutrients: Nutrients({'energy_kcal': 100, 'salt_g': 1.5}),
            references: {'salt_g': 6},
          ),
        ),
      ),
    );
    expect(find.text('Salt'), findsOneWidget);
    expect(find.text('Sodium 600 mg'), findsOneWidget);
    expect(find.text('Sodium'), findsNothing);
  });
}
