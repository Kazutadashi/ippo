// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the sleep module, from saving events to reading them back,
/// with real files in temporary folders.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/module.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/sleep/sleep_actions.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';
import 'package:ippo/modules/sleep/sleep_module.dart';
import 'package:ippo/modules/sleep/sleep_moment.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';

final DateTime monday = DateTime(2026, 11, 16);
final DateTime tuesday = DateTime(2026, 11, 17);
const String mondayText = '2026-11-16';
const String tuesdayText = '2026-11-17';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;
  late SleepActions actions;

  SleepLog currentLog() => SleepLog.fromEvents(appState.eventLog!.events);

  Future<SleepLog> logFromDisk() async {
    await appState.reloadEvents();
    return currentLog();
  }

  Future<void> wokeUp(DateTime day, ClockTime time) {
    return actions.recordMoment(
      kind: MomentKind.wokeUp,
      day: day,
      at: wakeUpMoment(day, time),
    );
  }

  Future<void> wentToBed(DateTime day, ClockTime time, ClockTime? woke) {
    return actions.recordMoment(
      kind: MomentKind.wentToBed,
      day: day,
      at: bedtimeMoment(day, time, woke),
    );
  }

  setUp(() async {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);
    actions = SleepActions(appState);
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  test('a bedtime after midnight is saved for the day before', () async {
    await wokeUp(monday, const ClockTime(7, 0));
    await wentToBed(monday, const ClockTime(1, 0), const ClockTime(7, 0));

    final file = File(
      '${dataFolder.path}/events/${appState.settings!.deviceId}.jsonl',
    );
    final event =
        jsonDecode(file.readAsLinesSync().last) as Map<String, Object?>;
    expect(event['module'], 'sleep');
    expect(event['type'], 'went_to_bed_recorded');
    final data = event['data'] as Map<String, Object?>;
    expect(data['date'], mondayText);
    // The moment itself is on the next calendar day.
    expect(data['at'] as String, startsWith('2026-11-17T01:00:00'));

    final bedtime = (await logFromDisk()).bedtimeOf(mondayText)!;
    expect(bedtime.clock, const ClockTime(1, 0));
    expect(bedtime.isAfterMidnight, isTrue);
    expect(bedtime.calendarDate, tuesdayText);
  });

  test('a bedtime before midnight stays on the same day', () async {
    await wokeUp(monday, const ClockTime(7, 0));
    await wentToBed(monday, const ClockTime(23, 15), const ClockTime(7, 0));

    final bedtime = (await logFromDisk()).bedtimeOf(mondayText)!;
    expect(bedtime.isAfterMidnight, isFalse);
  });

  test('sleep before a day: last bedtime to this wake-up', () async {
    await wentToBed(monday, const ClockTime(23, 30), const ClockTime(7, 0));
    await wokeUp(tuesday, const ClockTime(6, 45));

    final log = await logFromDisk();
    expect(log.sleepBefore(tuesdayText), const Duration(hours: 7, minutes: 15));
    expect(log.sleepBefore(mondayText), isNull);
  });

  test('changing, deleting and restoring a wake-up', () async {
    await wokeUp(monday, const ClockTime(7, 0));
    final wakeUp = currentLog().wakeUpOn(mondayText)!;

    await actions.changeMoment(
      wakeUp,
      wakeUpMoment(monday, const ClockTime(6, 30)),
    );
    expect(
      (await logFromDisk()).wakeUpOn(mondayText)!.clock,
      const ClockTime(6, 30),
    );

    await actions.deleteMoment(wakeUp);
    expect((await logFromDisk()).wakeUpOn(mondayText), isNull);
    await actions.restoreMoment(wakeUp);
    expect((await logFromDisk()).wakeUpOn(mondayText), isNotNull);
  });

  test('the latest wake-up and bedtime give the starting guesses', () async {
    expect(currentLog().latest(MomentKind.wokeUp), isNull);
    await wokeUp(monday, const ClockTime(7, 0));
    await wokeUp(tuesday, const ClockTime(6, 15));

    final log = await logFromDisk();
    expect(log.latest(MomentKind.wokeUp)!.clock, const ClockTime(6, 15));
    expect(log.latest(MomentKind.wentToBed), isNull);
  });

  test('naps are listed earliest first', () async {
    for (final start in [const ClockTime(16, 0), const ClockTime(13, 0)]) {
      await actions.recordNap(
        day: monday,
        period: napPeriod(
          monday,
          start,
          ClockTime(start.hour, start.minute + 20),
        ),
      );
    }

    final naps = (await logFromDisk()).napsOn(mondayText);
    expect(naps.map((nap) => nap.startClock), [
      const ClockTime(13, 0),
      const ClockTime(16, 0),
    ]);
  });

  group('home tiles', () {
    const module = SleepModule();

    test('show "–" until something is logged', () {
      expect(describeTiles(module.todayFacts(appState, monday)), [
        'Sleep: – | Not logged yet',
        'Awake for: – | Not logged yet',
      ]);
    });

    test('sleep before today, and awake since waking up', () async {
      await wentToBed(monday, const ClockTime(23, 0), const ClockTime(7, 0));
      await wokeUp(tuesday, const ClockTime(6, 30));

      final morning = DateTime(2026, 11, 17, 9, 15);
      expect(describeTiles(module.todayFacts(appState, morning)), [
        'Sleep: 7 h 30 min | 23:00 – 06:30',
        'Awake for: 2 h 45 min | since 06:30',
      ]);
    });

    test('at 01:00, the day before is still today', () async {
      await wokeUp(monday, const ClockTime(7, 0));
      final lateNight = DateTime(2026, 11, 17, 1, 0);

      expect(
        describeTiles(module.todayFacts(appState, lateNight))[1],
        'Awake for: 18 h | since 07:00',
      );
    });

    test('after going to bed, awake for is the whole day', () async {
      await wokeUp(monday, const ClockTime(7, 0));
      await wentToBed(monday, const ClockTime(1, 0), const ClockTime(7, 0));
      final lateNight = DateTime(2026, 11, 17, 2, 0);

      expect(
        describeTiles(module.todayFacts(appState, lateNight))[1],
        'Awake for: 18 h | 07:00 – 01:00',
      );
    });
  });

  test('invalid sleep data from other tools is counted', () async {
    await appState.writeEvent(
      module: 'sleep',
      type: 'woke_up_recorded',
      data: {'date': mondayText, 'at': 'this morning'},
    );
    await appState.writeEvent(
      module: 'sleep',
      type: 'nap_recorded',
      data: {
        'date': mondayText,
        // Ends before it starts.
        'started_at': '2026-11-16T15:00:00.000+00:00',
        'ended_at': '2026-11-16T14:00:00.000+00:00',
      },
    );

    final log = await logFromDisk();
    expect(log.invalidCount, 2);
    expect(log.wakeUpOn(mondayText), isNull);
  });

  test('clock times are shown as lived, in any time zone', () async {
    await appState.writeEvent(
      module: 'sleep',
      type: 'went_to_bed_recorded',
      data: {'date': mondayText, 'at': '2026-11-17T00:30:00.000+09:00'},
    );

    final bedtime = (await logFromDisk()).bedtimeOf(mondayText)!;
    expect(bedtime.clock, const ClockTime(0, 30));
    expect(bedtime.calendarDate, tuesdayText);
  });
}

/// Writes home tiles as `Label: value | detail`, for comparing.
List<String> describeTiles(List<TodayFact> facts) => [
  for (final fact in facts) '${fact.label}: ${fact.value} | ${fact.detail}',
];
