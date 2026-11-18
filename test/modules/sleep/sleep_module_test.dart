// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the sleep module, from saving events to reading them back,
/// with real files in temporary folders.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/events/timestamp.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/sleep/sleep_actions.dart';
import 'package:ippo/modules/sleep/sleep_episode.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';
import 'package:ippo/modules/sleep/sleep_module.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';

final DateTime monday = DateTime(2026, 11, 16);
const String mondayText = '2026-11-16';

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

  Future<void> recordNight(DateTime wakeDay, ClockTime bed, ClockTime woke) {
    return actions.recordSleep(
      day: wakeDay,
      kind: SleepKind.night,
      period: nightPeriod(wakeDay, bed, woke),
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

  test('a night is saved as the data format says', () async {
    await recordNight(monday, const ClockTime(23, 30), const ClockTime(7, 0));

    final file = File(
      '${dataFolder.path}/events/${appState.settings!.deviceId}.jsonl',
    );
    final event =
        jsonDecode(file.readAsLinesSync().last) as Map<String, Object?>;
    expect(event['module'], 'sleep');
    expect(event['type'], 'sleep_recorded');
    final data = event['data'] as Map<String, Object?>;
    expect(data['date'], mondayText);
    expect(data['kind'], 'night');
    // Exact moments with the local offset; the clock times are kept.
    expect(
      parseTimestamp(data['started_at'] as String),
      DateTime(2026, 11, 15, 23, 30).toUtc(),
    );
    expect(data['started_at'] as String, startsWith('2026-11-15T23:30:00'));
    expect(data['ended_at'] as String, startsWith('2026-11-16T07:00:00'));
  });

  test('a night counts for the day you woke up', () async {
    await recordNight(monday, const ClockTime(23, 30), const ClockTime(7, 0));

    final log = await logFromDisk();
    final night = log.nightOn(mondayText)!;
    expect(night.startClock, const ClockTime(23, 30));
    expect(night.endClock, const ClockTime(7, 0));
    expect(night.duration, const Duration(hours: 7, minutes: 30));
    expect(log.nightOn('2026-11-15'), isNull);
  });

  test('naps are listed earliest first, apart from the night', () async {
    await recordNight(monday, const ClockTime(23, 0), const ClockTime(7, 0));
    for (final start in [const ClockTime(16, 0), const ClockTime(13, 0)]) {
      await actions.recordSleep(
        day: monday,
        kind: SleepKind.nap,
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

  test('the last night gives the starting guess', () async {
    expect(currentLog().lastNight(), isNull);
    await recordNight(monday, const ClockTime(23, 0), const ClockTime(7, 0));
    await recordNight(
      addDays(monday, 1),
      const ClockTime(0, 15),
      const ClockTime(6, 45),
    );

    final last = (await logFromDisk()).lastNight()!;
    expect(last.startClock, const ClockTime(0, 15));
    expect(last.endClock, const ClockTime(6, 45));
  });

  test('changing, deleting and restoring a night', () async {
    await recordNight(monday, const ClockTime(23, 0), const ClockTime(7, 0));
    final night = currentLog().nightOn(mondayText)!;

    await actions.changeSleep(
      night.id,
      nightPeriod(monday, const ClockTime(22, 30), const ClockTime(6, 30)),
    );
    final changed = (await logFromDisk()).nightOn(mondayText)!;
    expect(changed.startClock, const ClockTime(22, 30));
    expect(changed.kind, SleepKind.night);

    await actions.deleteSleep(night.id);
    expect((await logFromDisk()).nightOn(mondayText), isNull);
    await actions.restoreSleep(night.id);
    expect((await logFromDisk()).nightOn(mondayText), isNotNull);
  });

  test('the home summary says how long you slept, and naps', () async {
    const module = SleepModule();
    expect(module.summarizeToday(appState), 'Nothing logged today');

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    await recordNight(
      todayStart,
      const ClockTime(23, 0),
      const ClockTime(6, 30),
    );
    await actions.recordSleep(
      day: todayStart,
      kind: SleepKind.nap,
      period: napPeriod(
        todayStart,
        const ClockTime(14, 0),
        const ClockTime(14, 30),
      ),
    );

    expect(module.summarizeToday(appState), 'Slept 7 h 30 min · 1 nap');
  });

  test('invalid sleep data from other tools is counted', () async {
    // Ends before it starts.
    await appState.writeEvent(
      module: 'sleep',
      type: 'sleep_recorded',
      data: {
        'date': mondayText,
        'kind': 'night',
        'started_at': '2026-11-16T07:00:00.000+00:00',
        'ended_at': '2026-11-15T23:00:00.000+00:00',
      },
    );
    // Unknown kind.
    await appState.writeEvent(
      module: 'sleep',
      type: 'sleep_recorded',
      data: {
        'date': mondayText,
        'kind': 'hibernation',
        'started_at': '2026-11-15T23:00:00.000+00:00',
        'ended_at': '2026-11-16T07:00:00.000+00:00',
      },
    );

    final log = await logFromDisk();
    expect(log.invalidCount, 2);
    expect(log.episodes, isEmpty);
  });

  test('clock times are shown as lived, in any time zone', () async {
    // A night recorded at UTC+9, read on a device in any time zone.
    await appState.writeEvent(
      module: 'sleep',
      type: 'sleep_recorded',
      data: {
        'date': mondayText,
        'kind': 'night',
        'started_at': '2026-11-15T23:30:00.000+09:00',
        'ended_at': '2026-11-16T07:00:00.000+09:00',
      },
    );

    final night = (await logFromDisk()).nightOn(mondayText)!;
    expect(night.startClock, const ClockTime(23, 30));
    expect(night.endClock, const ClockTime(7, 0));
    expect(night.duration, const Duration(hours: 7, minutes: 30));
  });
}
