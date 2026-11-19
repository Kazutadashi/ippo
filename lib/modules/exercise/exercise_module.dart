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
    final log = ExerciseLog.of(appState);
    final today = formatDate(currentDay(now));
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
    return [
      TodayFact(
        label: 'Exercise',
        value: setCount == 0
            ? TodayFact.unknownValue
            : (setCount == 1 ? '1 set' : '$setCount sets'),
        note: setCount == 0 ? 'No sets logged yet' : null,
        // The totals, one per line.
        details: [
          if (reps > 0) TileDetail('$reps reps'),
          if (seconds > 0) TileDetail('$seconds s held'),
        ],
      ),
      _lastSetFact(log, lastSet, now),
    ];
  }

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);
}

/// The "Last set" tile: how long ago the last set was logged, then the
/// exercise and how much.
TodayFact _lastSetFact(ExerciseLog log, ExerciseSet? lastSet, DateTime now) {
  if (lastSet == null) {
    return const TodayFact(
      label: 'Last set',
      value: TodayFact.unknownValue,
      note: 'Not logged yet',
    );
  }
  final exercise = log.exercises[lastSet.exerciseId];
  final unit = exercise?.measuredIn == MeasuredIn.seconds ? 's' : 'reps';
  final elapsed = now.toUtc().difference(lastSet.loggedAtUtc);
  return TodayFact(
    label: 'Last set',
    value: formatTimeAgo(elapsed.isNegative ? Duration.zero : elapsed),
    details: [
      TileDetail(exercise?.name ?? 'Exercise'),
      TileDetail('${lastSet.value} $unit'),
    ],
  );
}
