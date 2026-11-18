// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the sleep screen: woke up on the left, went to bed on the
/// right, each saved on its own, with the calendar day written below.
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
  late AppState appState;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  Future<void> openSleepScreen(WidgetTester tester) async {
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
    await tester.pumpWidget(MaterialApp(home: SleepScreen(appState: appState)));
  }

  testWidgets('woke up is on the left, went to bed on the right', (
    tester,
  ) async {
    await openSleepScreen(tester);

    final wokeUpLeft = tester.getTopLeft(find.text('Woke up')).dx;
    final wentToBedLeft = tester.getTopLeft(find.text('Went to bed')).dx;
    expect(wokeUpLeft, lessThan(wentToBedLeft));
    // The first guesses, before anything was logged.
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
    // Each side has its own Save button.
    expect(find.text('Save'), findsNWidgets(2));
  });

  testWidgets('the calendar day is written under each time', (tester) async {
    await openSleepScreen(tester);

    final day = currentSleepDay(DateTime.now());
    // Woke up at 07:00 and to bed at 23:00: both on the same day.
    expect(find.text(formatShortDate(day)), findsNWidgets(2));
  });

  testWidgets('saving the wake-up keeps the bedtime open', (tester) async {
    await openSleepScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save').first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // The wake-up is now information with an Edit button; the bedtime
    // still has its field and Save button.
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    final date = formatDate(currentSleepDay(DateTime.now()));
    final log = SleepLog.fromEvents(appState.eventLog!.events);
    expect(log.wakeUpOn(date)!.clock, const ClockTime(7, 0));
    expect(log.bedtimeOf(date), isNull);
  });

  testWidgets('the layout fits a narrow phone screen', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSleepScreen(tester);

    // An overflow would make the test framework report an error.
    expect(tester.takeException(), isNull);
  });
}
