// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: exercises and the sets done each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'exercise.dart';
import 'exercise_log.dart';
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

  /// For example: Sets 6 · Reps 120 · Held 90 s.
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final log = ExerciseLog.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(now);
    var setCount = 0;
    var reps = 0;
    var seconds = 0;
    for (final exercise in log.activeExercises) {
      for (final set in log.setsOn(today, exercise.id)) {
        setCount++;
        if (exercise.measuredIn == MeasuredIn.reps) {
          reps += set.value;
        } else {
          seconds += set.value;
        }
      }
    }
    return [
      if (setCount > 0) TodayFact('Sets', '$setCount'),
      if (reps > 0) TodayFact('Reps', '$reps'),
      if (seconds > 0) TodayFact('Held', '$seconds s'),
    ];
  }

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);
}
