// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the sleep screen: entering a night in one tap, and showing it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/sleep/screens/sleep_screen.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';
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

  testWidgets('a night is saved with one tap and then shown', (tester) async {
    final appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    // Real file access needs runAsync inside widget tests.
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
    });
    await tester.pumpWidget(MaterialApp(home: SleepScreen(appState: appState)));

    // The first guess, before any night was logged.
    expect(find.text('Bed 23:00'), findsOneWidget);
    expect(find.text('Woke 07:00'), findsOneWidget);
    expect(find.text('8 h'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save night'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Save night'), findsNothing);
    expect(find.text('23:00 → 07:00'), findsOneWidget);
    final night = SleepLog.fromEvents(appState.eventLog!.events)
        .nightOn(formatDate(DateTime.now()))!;
    expect(night.endClock, const ClockTime(7, 0));
  });
}
