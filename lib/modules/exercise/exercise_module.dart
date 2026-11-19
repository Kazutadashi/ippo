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

  /// Two tiles: how many exercises were done on [day], one dot each;
  /// and which of them beat their last session, biggest gain first.
  /// Both work with any number of exercises.
  @override
  List<TodayFact> dayFacts(AppState appState, DateTime day, DateTime now) {
    final log = ExerciseLog.of(appState);
    final exercises = log.activeExercises;
    if (exercises.isEmpty) {
      return const [
        TodayFact(
          label: 'Exercise',
          value: TodayFact.unknownValue,
          note: 'No exercises yet',
        ),
        TodayFact(
          label: 'Beat last time',
          value: TodayFact.unknownValue,
          note: 'No exercises yet',
        ),
      ];
    }
    final date = formatDate(day);
    final isToday = day == currentDay(now);
    final done = [
      for (final exercise in exercises)
        if (log.setsOn(date, exercise.id).isNotEmpty) exercise,
    ];
    return [
      TodayFact(
        label: 'Exercise',
        value: '${done.length} of ${exercises.length}',
        aside: _ExerciseDots(exercises: exercises, done: done),
        // On a rest day, when the last workout was.
        note: done.isEmpty
            ? _sinceLastWorkout(log, day, isToday: isToday)
            : null,
      ),
      _beatLastTime(log, done, date, isToday: isToday),
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

/// The "Beat last time" tile: how many of the exercises [done] on
/// [date] had a best set better than their last session's, and by how
/// much, biggest gain first. Exercises done for the first time have
/// nothing to beat and are left out.
TodayFact _beatLastTime(
  ExerciseLog log,
  List<Exercise> done,
  String date, {
  required bool isToday,
}) {
  if (done.isEmpty) {
    return TodayFact(
      label: 'Beat last time',
      value: TodayFact.unknownValue,
      note: isToday ? 'No sets yet today' : 'No sets that day',
    );
  }
  final gains = <({String name, int gain, String unit})>[];
  for (final exercise in done) {
    final previous = log.previousSessionOf(exercise.id, date);
    if (previous == null || previous.sets.isEmpty) {
      continue;
    }
    final best = _best(log.setsOn(date, exercise.id).map((set) => set.value));
    final bestBefore = _best(previous.sets.map((set) => set.value));
    if (best > bestBefore) {
      final reps = best - bestBefore == 1 ? 'rep' : 'reps';
      gains.add((
        name: exercise.name,
        gain: best - bestBefore,
        unit: exercise.measuredIn == MeasuredIn.reps ? reps : 's',
      ));
    }
  }
  gains.sort((first, second) => second.gain.compareTo(first.gain));
  if (gains.isEmpty) {
    return TodayFact(
      label: 'Beat last time',
      value: '0',
      note: isToday ? 'Not yet today' : 'Nothing that day',
    );
  }
  return TodayFact(
    label: 'Beat last time',
    value: gains.length == 1 ? '1 exercise' : '${gains.length} exercises',
    // The two biggest gains, one per line.
    details: [
      for (final gain in gains.take(2))
        TileDetail('${gain.name} +${gain.gain} ${gain.unit}'),
    ],
  );
}

/// The largest of [values], which are never empty here.
int _best(Iterable<int> values) => values.reduce(max);

/// One dot per exercise, in the theme's accent: filled when it was done
/// that day, an empty ring when not. Like the habit dots beside "3 of 4".
class _ExerciseDots extends StatelessWidget {
  const _ExerciseDots({required this.exercises, required this.done});

  final List<Exercise> exercises;
  final List<Exercise> done;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: done.isEmpty
          ? 'None done yet'
          : 'Done: ${done.map((exercise) => exercise.name).join(', ')}',
      child: ExcludeSemantics(
        child: Wrap(
          // Beside the value, the dots line up with the tile's right
          // edge, on a second line too if there are many.
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final exercise in exercises)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done.contains(exercise) ? color : null,
                  border: done.contains(exercise)
                      ? null
                      : Border.all(color: color, width: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
