// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the nap form: the one-tap lengths, and moving a nap to another
/// day.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/clock_time.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/sleep/screens/nap_form_screen.dart';
import 'package:ippo/modules/sleep/sleep_actions.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';
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

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 918);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
    });
  }

  testWidgets('a length keeps the end and moves the start', (tester) async {
    await startApp(tester);
    final day = today();
    await tester.runAsync(
      () => SleepActions(appState).recordNap(
        day: day,
        period: napPeriod(day, const ClockTime(14, 0), const ClockTime(15, 0)),
      ),
    );
    final nap = SleepLog.of(appState).napsOn(formatDate(day)).single;
    await tester.pumpWidget(
      MaterialApp(
        home: NapFormScreen.editNap(appState: appState, nap: nap),
      ),
    );

    // An hour is chosen; every length reads in minutes, on one line.
    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    await tester.tap(find.text('20 min'));
    await tester.pump();
    expect(find.text('14:40'), findsWidgets);
    expect(find.text('15:00'), findsWidgets);
    expect(find.text('20 min'), findsWidgets);
  });

  testWidgets('a nap moved to another day is saved with its new date', (
    tester,
  ) async {
    await startApp(tester);
    final day = today();
    final yesterday = addDays(day, -1);
    await tester.runAsync(
      () => SleepActions(appState).recordNap(
        day: day,
        period: napPeriod(day, const ClockTime(14, 0), const ClockTime(15, 0)),
      ),
    );
    final nap = SleepLog.of(appState).napsOn(formatDate(day)).single;
    await tester.runAsync(
      () => SleepActions(appState).changeNap(
        nap.id,
        napPeriod(yesterday, const ClockTime(14, 0), const ClockTime(15, 0)),
        date: yesterday,
      ),
    );
    final log = SleepLog.of(appState);
    expect(log.napsOn(formatDate(day)), isEmpty);
    expect(log.napsOn(formatDate(yesterday)).single.startClock.hour, 14);
  });
}
