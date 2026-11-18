// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: exercises and the sets done each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'exercise.dart';
import 'exercise_log.dart';
import 'exercise_set.dart';
import 'screens/exercise_home_screen.dart';

/// The exercise module, as seen by the core app.
class ExerciseModule implements IppoModule {
  /// Creates the module.
  const ExerciseModule();

  @override
  String get moduleName => exerciseModuleName;

  @override
  String get title => 'Exercise';

  @override
  IconData get icon => Icons.fitness_center;

  /// Two tiles: today's sets, and the last set.
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final log = ExerciseLog.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(now);
    var setCount = 0;
    var reps = 0;
    var seconds = 0;
    ExerciseSet? lastSet;
    for (final exercise in log.activeExercises) {
      for (final set in log.setsOn(today, exercise.id)) {
        setCount++;
        if (exercise.measuredIn == MeasuredIn.reps) {
          reps += set.value;
        } else {
          seconds += set.value;
        }
        if (lastSet == null || set.loggedAtUtc.isAfter(lastSet.loggedAtUtc)) {
          lastSet = set;
        }
      }
    }
    final totals = [
      if (reps > 0) '$reps reps',
      if (seconds > 0) '$seconds s held',
    ];
    return [
      TodayFact(
        icon: Icons.fitness_center,
        label: 'Exercise',
        value: setCount == 0
            ? TodayFact.unknownValue
            : (setCount == 1 ? '1 set' : '$setCount sets'),
        detail: setCount == 0 ? 'No sets logged yet' : totals.join(' · '),
      ),
      _lastSetFact(log, lastSet, now),
    ];
  }

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);
}

/// The "Last set" tile: how long ago the last set was logged, and what it
/// was.
TodayFact _lastSetFact(ExerciseLog log, ExerciseSet? lastSet, DateTime now) {
  if (lastSet == null) {
    return const TodayFact(
      icon: Icons.schedule,
      label: 'Last set',
      value: TodayFact.unknownValue,
      detail: 'Not logged yet',
    );
  }
  final exercise = log.exercises[lastSet.exerciseId];
  final unit = exercise?.measuredIn == MeasuredIn.seconds ? 's' : 'reps';
  final elapsed = now.toUtc().difference(lastSet.loggedAtUtc);
  return TodayFact(
    icon: Icons.schedule,
    label: 'Last set',
    value: formatTimeAgo(elapsed.isNegative ? Duration.zero : elapsed),
    detail: '${exercise?.name ?? 'Exercise'} · ${lastSet.value} $unit',
  );
}
