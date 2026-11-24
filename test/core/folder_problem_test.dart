// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks what the app frame shows when the data folder cannot be read:
/// a strip above the tabs while it is gone, and, if it is missing at
/// start, a screen saying so instead of the welcome.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/home_screen.dart';
import 'package:ippo/core/storage/settings_file.dart';
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
    if (dataFolder.existsSync()) {
      dataFolder.deleteSync(recursive: true);
    }
  });

  AppState makeAppState() => AppState(
    settingsFile: SettingsFile(settingsFolder.path),
    isAndroid: false,
    defaultDeviceName: 'my-desktop',
  );

  testWidgets('a folder that goes away shows a strip until it is back', (
    tester,
  ) async {
    final appState = makeAppState();
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
    });
    await tester.pumpWidget(MaterialApp(home: HomeScreen(appState: appState)));
    await tester.pump();
    const strip = 'The data folder cannot be read. Shown as last read.';
    expect(find.text(strip), findsNothing);

    await tester.runAsync(() async {
      dataFolder.deleteSync(recursive: true);
      await appState.reloadEvents();
    });
    await tester.pump();
    expect(find.text(strip), findsOneWidget);

    await tester.runAsync(() async {
      dataFolder.createSync();
      await appState.reloadEvents();
    });
    await tester.pump();
    expect(find.text(strip), findsNothing);
  });

  testWidgets('a folder missing at start is said, not the welcome', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final firstRun = makeAppState();
      await firstRun.load();
      await firstRun.chooseLinuxDataFolder(dataFolder.path);
      dataFolder.deleteSync(recursive: true);
    });
    final appState = makeAppState();
    await tester.runAsync(appState.load);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(appState: appState)));
    await tester.pump();
    expect(find.text('Ippo cannot reach your data folder.'), findsOneWidget);
    expect(find.textContaining(dataFolder.path), findsOneWidget);

    await tester.runAsync(() async {
      dataFolder.createSync();
      await tester.tap(find.text('Try again'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Ippo cannot reach your data folder.'), findsNothing);
  });
}
