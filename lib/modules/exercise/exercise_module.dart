// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: exercises and the sets done each day.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'exercise.dart';
import 'exercise_log.dart';
import 'screens/exercise_home_screen.dart';

/// The exercise module, as seen by the core app.
class ExerciseModule extends IppoModule {
  /// Creates the module.
  const ExerciseModule();

  @override
  String get moduleName => exerciseModuleName;

  @override
  String get title => 'Exercise';

  @override
  IconData get icon => Icons.fitness_center;

  @override
  Color get color => const Color(0xFFD9694F); // coral

  /// Two tiles: today's sets, and the last set.
  @override
  List<TodayFact> dayFacts(AppState appState, DateTime day, DateTime now) {
    final log = ExerciseLog.of(appState);
    final date = formatDate(day);
    // One column per exercise done that day: its best set, the number
    // that shows progress over time.
    final bestSets = <TileDetail>[];
    for (final exercise in log.activeExercises) {
      final sets = log.setsOn(date, exercise.id);
      if (sets.isEmpty) {
        continue;
      }
      final best = sets.map((set) => set.value).reduce(max);
      final unit = exercise.measuredIn == MeasuredIn.reps ? 'reps' : 's';
      // A small "+2" when this beats the best set of the session before.
      final before = _bestBefore(log, exercise.id, day);
      bestSets.add(
        TileDetail(
          '$best $unit',
          label: exercise.name,
          badge: before != null && best > before ? '+${best - before}' : null,
        ),
      );
    }
    if (bestSets.isEmpty) {
      return [
        TodayFact(
          label: 'Exercise',
          value: TodayFact.unknownValue,
          note: _sinceLastWorkout(log, day, isToday: day == currentDay(now)),
          isWide: true,
        ),
      ];
    }
    final count = bestSets.length;
    return [
      TodayFact(
        label: 'Exercise: best sets',
        value: count == 1 ? '1 exercise' : '$count exercises',
        details: bestSets,
        isWide: true,
      ),
    ];
  }

  @override
  TileDetail? weekSummary(AppState appState, DateTime day) {
    final log = ExerciseLog.of(appState);
    if (log.activeExercises.isEmpty) {
      return null;
    }
    var workoutDays = 0;
    for (var back = 0; back < 7; back++) {
      final date = formatDate(addDays(day, -back));
      final trained = log.activeExercises.any(
        (exercise) => log.setsOn(date, exercise.id).isNotEmpty,
      );
      if (trained) {
        workoutDays++;
      }
    }
    return TileDetail(
      workoutDays == 1 ? '1 day' : '$workoutDays days',
      label: 'Workouts',
    );
  }

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);
}

/// A note for a day without sets: when the last workout before it was,
/// such as "Last workout 2 days ago" (or "… before", looking back at an
/// earlier day), or that there is none yet.
String _sinceLastWorkout(
  ExerciseLog log,
  DateTime day, {
  required bool isToday,
}) {
  DateTime? last;
  for (final set in log.sets) {
    final setDay = parseDate(set.date);
    if (set.isDeleted || setDay == null || !setDay.isBefore(day)) {
      continue;
    }
    if (last == null || setDay.isAfter(last)) {
      last = setDay;
    }
  }
  if (last == null) {
    return 'No sets logged yet';
  }
  final days = day.difference(last).inDays;
  if (days == 1) {
    return isToday ? 'Last workout yesterday' : 'Last workout the day before';
  }
  return 'Last workout $days days ${isToday ? 'ago' : 'before'}';
}

/// The best set of [exerciseId] on the last day before [day] that it was
/// done, or null if it never was.
int? _bestBefore(ExerciseLog log, String exerciseId, DateTime day) {
  String? lastDate;
  for (final set in log.sets) {
    final setDay = parseDate(set.date);
    if (set.isDeleted ||
        set.exerciseId != exerciseId ||
        setDay == null ||
        !setDay.isBefore(day)) {
      continue;
    }
    if (lastDate == null || set.date.compareTo(lastDate) > 0) {
      lastDate = set.date;
    }
  }
  if (lastDate == null) {
    return null;
  }
  return log.setsOn(lastDate, exerciseId).map((set) => set.value).reduce(max);
}
