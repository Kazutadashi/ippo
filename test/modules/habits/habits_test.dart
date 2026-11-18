// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the habits module: saving habits and days, the ✓ / ✗
/// cycle, the home tiles, and the grid.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/module.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/habits/habit_actions.dart';
import 'package:ippo/modules/habits/habit_log.dart';
import 'package:ippo/modules/habits/habits_module.dart';
import 'package:ippo/modules/habits/screens/habits_screen.dart';
import 'package:material_ui/material_ui.dart';

const String day = '2026-11-17';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;
  late HabitActions actions;

  HabitLog currentLog() => HabitLog.fromEvents(appState.eventLog!.events);

  Future<HabitLog> logFromDisk() async {
    await appState.reloadEvents();
    return currentLog();
  }

  Future<void> setUpApp() async {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);
    actions = HabitActions(appState);
  }

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  group('data', () {
    setUp(setUpApp);

    test('a new habit is a yes/no habit, once a day', () async {
      await actions.createHabit(' Read 10 pages ');

      final file = File(
        '${dataFolder.path}/events/${appState.settings!.deviceId}.jsonl',
      );
      final event =
          jsonDecode(file.readAsLinesSync().last) as Map<String, Object?>;
      expect(event['module'], 'habits');
      expect(event['type'], 'habit_created');
      expect(event['data'], {
        'name': 'Read 10 pages',
        'value_type': 'yes_no',
        'frequency': {'times': 1, 'per_days': 1},
      });
      expect((await logFromDisk()).shownHabits.single.name, 'Read 10 pages');
    });

    test('tapping a day cycles: nothing, done, not done, nothing', () async {
      final habitId = (await actions.createHabit('Read')).id;

      expect(currentLog().markOn(habitId, day), DayMark.none);
      await actions.cycleDay(habitId, day, currentLog());
      expect((await logFromDisk()).markOn(habitId, day), DayMark.done);
      await actions.cycleDay(habitId, day, currentLog());
      expect((await logFromDisk()).markOn(habitId, day), DayMark.notDone);
      await actions.cycleDay(habitId, day, currentLog());
      expect((await logFromDisk()).markOn(habitId, day), DayMark.none);
    });

    test('"not done" is saved as an explicit no', () async {
      final habitId = (await actions.createHabit('Read')).id;
      await actions.recordDay(habitId, day, done: false);

      final entry = (await logFromDisk()).entriesOn(habitId, day).single;
      expect(entry.value, false);
    });

    test('days are kept apart', () async {
      final habitId = (await actions.createHabit('Read')).id;
      await actions.recordDay(habitId, day, done: true);

      final log = await logFromDisk();
      expect(log.markOn(habitId, day), DayMark.done);
      expect(log.markOn(habitId, '2026-11-16'), DayMark.none);
    });

    test('renaming, deleting and restoring a habit', () async {
      final habitId = (await actions.createHabit('Read')).id;
      await actions.recordDay(habitId, day, done: true);

      await actions.renameHabit(habitId, 'Read a book');
      expect((await logFromDisk()).shownHabits.single.name, 'Read a book');

      await actions.deleteHabit(habitId);
      final log = await logFromDisk();
      expect(log.shownHabits, isEmpty);
      // The past days stay in the data.
      expect(log.markOn(habitId, day), DayMark.done);

      await actions.restoreHabit(habitId);
      expect((await logFromDisk()).shownHabits, hasLength(1));
    });

    test('home tiles: done today, and what is left', () async {
      const module = HabitsModule();
      final now = DateTime(2026, 11, 17, 20);
      expect(describeTiles(module.todayFacts(appState, now)), [
        'Habits: – | No habits yet',
        'To do: – | No habits yet',
      ]);

      final read = (await actions.createHabit('Read')).id;
      await actions.createHabit('Stretch');
      await actions.createHabit('Study');
      await actions.recordDay(read, day, done: true);

      expect(describeTiles(module.todayFacts(appState, now)), [
        'Habits: 1 / 3 | done today',
        'To do: 2 | Stretch, Study',
      ]);
    });
  });

  testWidgets('the grid: habits down, today on the left, tap to mark', (
    tester,
  ) async {
    await tester.runAsync(setUpApp);
    late String habitId;
    await tester.runAsync(() async {
      habitId = (await actions.createHabit('Read 10 pages')).id;
      await actions.createHabit('Stretch');
    });
    await tester.pumpWidget(
      MaterialApp(home: HabitsScreen(appState: appState)),
    );

    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('Stretch'), findsOneWidget);
    // Today's column is first: its date is left of yesterday's.
    final now = DateTime.now();
    final todayLeft = tester.getTopLeft(find.text('${now.day}').first).dx;
    final yesterday = addDays(DateTime(now.year, now.month, now.day), -1);
    final yesterdayLeft = tester
        .getTopLeft(find.text('${yesterday.day}').first)
        .dx;
    expect(todayLeft, lessThan(yesterdayLeft));

    // Tap today's cell for the first habit: it becomes done.
    final todayText = formatShortDate(DateTime(now.year, now.month, now.day));
    await tester.runAsync(() async {
      await tester.tap(
        find.bySemanticsLabel('Read 10 pages, $todayText: not recorded'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(currentLog().markOn(habitId, formatDate(now)), DayMark.done);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

/// Writes home tiles as `Label: value | detail`, for comparing.
List<String> describeTiles(List<TodayFact> facts) => [
  for (final fact in facts) '${fact.label}: ${fact.value} | ${fact.detail}',
];
