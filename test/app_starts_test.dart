// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the app starts on the right tab, that the home tab leads
/// to the modules, and that the chosen theme is applied.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/core/today_screen.dart';
import 'package:ippo/main.dart';
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

  AppState makeAppState() => AppState(
    settingsFile: SettingsFile(settingsFolder.path),
    isAndroid: false,
    defaultDeviceName: 'my-desktop',
  );

  /// Starts the app. Real file access needs runAsync in widget tests.
  Future<AppState> startApp(
    WidgetTester tester, {
    bool withDataFolder = true,
    Future<void> Function(AppState appState)? before,
  }) async {
    final appState = makeAppState();
    await tester.runAsync(() async {
      await appState.load();
      if (withDataFolder) {
        await appState.chooseLinuxDataFolder(dataFolder.path);
      }
      if (before != null) {
        await before(appState);
      }
    });
    await tester.pumpWidget(IppoApp(appState: appState));
    await tester.pump();
    return appState;
  }

  testWidgets('on first run, the app opens settings to choose a folder', (
    tester,
  ) async {
    await startApp(tester, withDataFolder: false);

    expect(find.text('Data folder'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Exercise'), findsOneWidget);
  });

  testWidgets('with a data folder, the app opens on Home', (tester) async {
    await startApp(tester);

    expect(find.text(greetingFor(DateTime.now())), findsOneWidget);
    expect(find.text(describeToday(DateTime.now())), findsOneWidget);
    expect(find.text('Nothing logged yet today.'), findsOneWidget);
    // Nothing logged yet: each module says so.
    expect(find.text('Nothing logged today'), findsNWidgets(3));
  });

  testWidgets('Home shows what was logged today', (tester) async {
    await startApp(
      tester,
      before: (appState) async {
        await appState.writeEvent(
          module: 'food',
          type: 'food_entry_recorded',
          data: {
            'date': formatDate(DateTime.now()),
            'meal': 'snack',
            'name': 'Apple',
            'nutrients': {'energy_kcal': 80},
          },
        );
      },
    );

    expect(find.text('1 entry · 80 kcal'), findsOneWidget);
    expect(
      find.text('Logged today: Food. Still to log: Exercise, Sleep.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a card on Home opens that module', (tester) async {
    await startApp(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Exercise'));
    await tester.pump();

    expect(find.text('New exercise'), findsOneWidget);
  });

  test('the greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Good evening');
  });

  testWidgets('dark mode and the accent colour are applied', (tester) async {
    await startApp(
      tester,
      before: (appState) async {
        await appState.setThemeMode('dark');
        await appState.setAccentColor('#FB8C00');
      },
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    // The theme is built from the chosen colour.
    final darkPrimary = app.darkTheme!.colorScheme.primary;
    final defaultPrimary = makeTheme(const Color(0xFF00897B));
    expect(darkPrimary, isNot(defaultPrimary));
  });
}

/// The dark theme's main colour for [accent], for comparing.
Color makeTheme(Color accent) => ColorScheme.fromSeed(
  seedColor: accent,
  brightness: Brightness.dark,
  dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
).primary;
