// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks the sleep screen: woke up on the left, went to bed on the
/// right, as dates and times, with one Save.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/sleep/screens/nap_form_screen.dart';
import 'package:ippo/modules/sleep/screens/sleep_screen.dart';
import 'package:ippo/modules/sleep/sleep_actions.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';
import 'package:ippo/modules/sleep/sleep_moment.dart';
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

  testWidgets('woke up on the left, went to bed on the right, one Save', (
    tester,
  ) async {
    await openSleepScreen(tester);

    final wokeUpLeft = tester.getTopLeft(find.text('Woke up')).dx;
    final wentToBedLeft = tester.getTopLeft(find.text('Went to bed')).dx;
    expect(wokeUpLeft, lessThan(wentToBedLeft));
    expect(find.text('Save'), findsOneWidget);
    // Woke up starts at the usual time; went to bed is not set yet.
    final day = today();
    expect(find.text(formatShortDate(day)), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Clear this day'), findsNothing);
  });

  testWidgets('saving in the morning records only the wake-up', (tester) async {
    await openSleepScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final date = formatDate(today());
    final log = SleepLog.fromEvents(appState.eventLog!.events);
    expect(log.wakeUpOn(date)!.clock, const ClockTime(7, 0));
    expect(log.bedtimeOf(date), isNull);
    expect(find.text('Clear this day'), findsOneWidget);
  });

  testWidgets('one tap saves waking up now; going to bed in the evening', (
    tester,
  ) async {
    await openSleepScreen(tester);

    final before = DateTime.now();
    await tester.runAsync(() async {
      await tester.tap(find.text('Woke up now'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final date = formatDate(today());
    var log = SleepLog.fromEvents(appState.eventLog!.events);
    final wakeUp = log.wakeUpOn(date)!;
    expect(wakeUp.clock, ClockTime(before.hour, before.minute));
    expect(find.text('Woke up now'), findsNothing);
    // Next comes the bedtime, also in one tap, but only in the evening
    // and night: in the morning it would make no sense.
    final hour = DateTime.now().hour;
    if (hour < 18 && hour >= dayStartHour) {
      expect(find.text('Going to bed now'), findsNothing);
      return;
    }
    expect(find.text('Going to bed now'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Going to bed now'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    log = SleepLog.fromEvents(appState.eventLog!.events);
    expect(log.bedtimeOf(date), isNotNull);
    expect(find.text('Going to bed now'), findsNothing);
  });

  testWidgets('saved times are shown, and can be cleared', (tester) async {
    await openSleepScreen(tester);
    final day = today();
    await tester.runAsync(() async {
      final actions = SleepActions(appState);
      await actions.recordMoment(
        kind: MomentKind.wokeUp,
        day: day,
        at: wakeUpMoment(day, const ClockTime(6, 15)),
      );
      await actions.recordMoment(
        kind: MomentKind.wentToBed,
        day: day,
        at: bedtimeMoment(day, const ClockTime(1, 30), const ClockTime(6, 15)),
      );
    });
    await tester.pump();

    expect(find.text('06:15'), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);
    // The bedtime is after midnight: the next calendar day is shown.
    expect(find.text(formatShortDate(addDays(day, 1))), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Clear this day'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final date = formatDate(day);
    final log = SleepLog.fromEvents(appState.eventLog!.events);
    expect(log.wakeUpOn(date), isNull);
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

  testWidgets('a nap length sets the start, keeping the end', (tester) async {
    await openSleepScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: NapFormScreen.addNap(appState: appState, day: today()),
      ),
    );

    await tester.tap(find.text('30 min'));
    await tester.pump();

    expect(find.text('30 min of sleep'), findsOneWidget);
  });
}
