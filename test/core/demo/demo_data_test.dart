// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the demo's made-up data (`demo_plan.dart` and each module's
/// `demoEvents`).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/events/event.dart';
import 'package:ippo/modules/all_modules.dart';
import 'package:ippo/modules/body/body_log.dart';
import 'package:ippo/modules/exercise/exercise_log.dart';
import 'package:ippo/modules/food/food_diary.dart';
import 'package:ippo/modules/habits/habit_log.dart';
import 'package:ippo/modules/sleep/sleep_log.dart';

void main() {
  // An afternoon, so today already has some entries but not all.
  final now = DateTime(2026, 11, 20, 15, 30);
  final text = demoEventFileForAllModules(now);
  final events = [
    for (final line in const LineSplitter().convert(text))
      Event.fromJsonLine(line),
  ];

  test('every line is a valid event, oldest first, none in the future', () {
    expect(events, isNotEmpty);
    for (var index = 1; index < events.length; index++) {
      expect(
        events[index].recordedAtUtc.isBefore(events[index - 1].recordedAtUtc),
        isFalse,
      );
    }
    expect(events.last.recordedAtUtc.isAfter(now.toUtc()), isFalse);
    expect({for (final event in events) event.id}.length, events.length);
  });

  test('it is small: well under half a megabyte', () {
    expect(utf8.encode(text).length, lessThan(500 * 1000));
  });

  test('every module has data, ending today', () {
    final day = formatDate(now);
    final habits = HabitLog.fromEvents(events);
    // A dozen shown; one given up (archived) and one deleted are hidden;
    // one was renamed and shows under its new name.
    expect(habits.shownHabits, hasLength(12));
    final names = [for (final habit in habits.shownHabits) habit.name];
    expect(names, contains('Read 10 pages'));
    expect(names, isNot(contains('Read')));
    expect(names, isNot(contains('Cold shower')));
    expect(names, isNot(contains('Strech')));
    expect(habits.entries.any((entry) => entry.date == day), isTrue);

    final food = FoodDiary.fromEvents(events);
    expect(food.foods, hasLength(10));
    // Breakfast and lunch are eaten by 15:30; dinner is not, yet.
    final today = food.entries.where((entry) => entry.date == day).toList();
    expect(today, isNotEmpty);
    expect(today.every((entry) => entry.time!.compareTo('15:30') < 0), isTrue);

    final exercise = ExerciseLog.fromEvents(events);
    expect(exercise.activeExercises, hasLength(12));
    // Today is a long session: more exercises than the Home tile shows.
    final doneToday = exercise.activeExercises
        .where((item) => exercise.setsOn(day, item.id).isNotEmpty)
        .length;
    expect(doneToday, greaterThan(4));
    expect(exercise.sets, isNotEmpty);
    expect(exercise.steps.any((steps) => steps.date == day), isTrue);

    final sleep = SleepLog.fromEvents(events);
    expect(sleep.wakeUpOn(day), isNotNull);
    expect(sleep.naps, isNotEmpty);

    final body = BodyLog.fromEvents(events);
    expect(body.sex, isNotNull);
    expect(body.weights, isNotEmpty);
    expect(body.targets, isNotEmpty);
  });

  test('the same moment gives the same demo', () {
    expect(demoEventFileForAllModules(now), text);
  });
}
