// SPDX-License-Identifier: GPL-3.0-or-later

/// Reads the example data folder at the top of the repository and checks
/// what the app makes of it.
///
/// The Python package checks the same answers in
/// `python/tests/test_example_folder.py`, so the app and the package are
/// known to agree. The folder holds every awkward case on purpose: a sync
/// conflict copy, a hidden file, a cut-off line, a backup, changes,
/// deletions, a bedtime after midnight and a time zone change.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/event_log.dart';
import 'package:ippo/core/events/event_log_reader.dart';
import 'package:ippo/core/storage/local_data_folder.dart';
import 'package:ippo/modules/body/body_log.dart';
import 'package:ippo/modules/exercise/exercise_log.dart';
import 'package:ippo/modules/food/food_diary.dart';
import 'package:ippo/modules/habits/habit_log.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';

void main() {
  late EventLog eventLog;

  setUpAll(() async {
    // Only read: nothing is ever written into the example folder.
    eventLog = await readEventLog(
      LocalDataFolder('example-data'),
      now: DateTime.utc(2026, 3, 5),
    );
  });

  test('every event is read once; the cut-off line is reported', () {
    expect(eventLog.events, hasLength(51));
    expect(eventLog.problems, hasLength(1));
    expect(eventLog.problems.single.reason, 'not valid JSON');
    expect(eventLog.newerVersionEventCount, 1);
    expect(eventLog.futureEventCount, 0);
  });

  test('habits: renames, deletions, latest value wins, cleared days', () {
    final log = HabitLog.fromEvents(eventLog.events);
    final habits = {for (final habit in log.shownHabits) habit.name: habit.id};
    expect(habits.keys, ['Read', 'Evening walk']);

    final read = habits['Read']!;
    final walk = habits['Evening walk']!;
    expect(log.markOn(read, '2026-03-01'), DayMark.done);
    expect(log.markOn(read, '2026-03-02'), DayMark.notDone);
    expect(log.markOn(read, '2026-03-03'), DayMark.done);
    expect(log.markOn(walk, '2026-03-01'), DayMark.notDone);
    expect(log.markOn(walk, '2026-03-02'), DayMark.none);
  });

  test('food: changed and deleted entries', () {
    final diary = FoodDiary.fromEvents(eventLog.events);
    expect(diary.totalOn('2026-03-01').energyKcal, 1040);
    expect(diary.totalOn('2026-03-02').energyKcal, 285);
  });

  test('food: the latest mark of a day counts; unmarked days are null', () {
    final diary = FoodDiary.fromEvents(eventLog.events);
    expect(diary.markOn('2026-03-01'), isTrue);
    expect(diary.markOn('2026-03-02'), isFalse);
    expect(diary.markOn('2026-03-03'), isNull);
  });

  test('events keep their app version and time zone when given', () {
    final marked = eventLog.events.firstWhere(
      (event) => event.id == '019c0040-0000-7000-8000-000000000040',
    );
    expect(marked.appVersion, '0.1.0');
    expect(marked.timeZone, 'America/New_York');
    expect(eventLog.events.first.timeZone, isNull);
  });

  test('exercise: changed and deleted sets', () {
    final log = ExerciseLog.fromEvents(eventLog.events);
    final ids = {for (final e in log.activeExercises) e.name: e.id};
    final pushUps = log.setsOn('2026-03-01', ids['Push-up']!);
    expect(pushUps.map((set) => set.value), [10, 12, 11]);
    expect(log.setsOn('2026-03-02', ids['Push-up']!).single.value, 14);
    expect(log.setsOn('2026-03-01', ids['Plank']!).single.value, 60);
  });

  test('sleep: after midnight, a changed wake-up, a time zone change', () {
    final log = SleepLog.fromEvents(eventLog.events);
    expect(log.bedtimeOf('2026-03-01')!.isAfterMidnight, isTrue);
    expect(
      log.sleepBefore('2026-03-02'),
      const Duration(hours: 6, minutes: 45),
    );
    expect(log.sleepBefore('2026-03-03'), const Duration(hours: 13));
    expect(log.napsOn('2026-03-02').single.duration.inMinutes, 30);
  });

  test('steps: changed in place, and deleted', () {
    final log = ExerciseLog.fromEvents(eventLog.events);
    expect(log.stepsOn('2026-03-02')!.steps, 6400);
    expect(log.stepsOn('2026-03-03'), isNull);
  });

  test('body: profile fields replaced one by one, a changed weight, '
      'a limit from its day', () {
    final log = BodyLog.fromEvents(eventLog.events);
    expect(log.sex, Sex.female);
    expect(log.birthYear, 1990);
    expect(log.heightCm, 169);
    expect(log.weightAsOf('2026-03-03'), 70.2);
    expect(log.energyTargetOn('2026-03-01'), isNull);
    expect(log.energyTargetOn('2026-03-03'), 1900);
  });

  test('food: vitamins and ingredients are kept', () {
    final diary = FoodDiary.fromEvents(eventLog.events);
    final milk = diary.foods.values.singleWhere(
      (food) => food.name == 'Fortified milk',
    );
    expect(milk.nutrientsPer100.values['vitamin_d_ug'], 1.1);
    expect(milk.nutrientsPer100.values['calcium_mg'], 120);
    expect(milk.ingredients, 'Milk, vitamin D3.');
  });
}
