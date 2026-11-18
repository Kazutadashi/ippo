// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the settings screen: information is shown as text, and the
/// device is renamed through the Edit button.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/settings/settings_screen.dart';
import 'package:ippo/core/storage/settings_file.dart';
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

  Future<void> openSettings(WidgetTester tester) async {
    // A tall screen, so every card is drawn at once.
    tester.view.physicalSize = const Size(800, 2400);
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
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(appState: appState)),
    );
  }

  testWidgets('this device is shown as information', (tester) async {
    await openSettings(tester);

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('my-desktop'), findsOneWidget);
    expect(find.text('Event file'), findsOneWidget);
    // The name is not a text field until Edit is tapped.
    expect(find.widgetWithText(TextField, 'my-desktop'), findsNothing);
  });

  testWidgets('Edit renames the device', (tester) async {
    await openSettings(tester);

    // Saving writes a real file. The rename starts when Edit is tapped,
    // so the whole interaction runs outside the test clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField).last, 'my-laptop');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('my-laptop'), findsOneWidget);
    expect(appState.settings!.deviceName, 'my-laptop');
  });

  testWidgets('Cancel keeps the old name', (tester) async {
    await openSettings(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'something else');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('my-desktop'), findsOneWidget);
    expect(appState.settings!.deviceName, 'my-desktop');
  });
}
