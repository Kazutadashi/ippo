// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: exercises and the sets done each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
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

  /// Lists today's sets per exercise, for example
  /// `Push-up 20, 20 · Plank 45`.
  @override
  String summarizeToday(AppState appState) {
    final log = ExerciseLog.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(DateTime.now());
    final parts = <String>[];
    for (final exercise in log.activeExercises) {
      final values = [
        for (final set in log.setsOn(today, exercise.id)) '${set.value}',
      ];
      if (values.isNotEmpty) {
        parts.add('${exercise.name} ${values.join(', ')}');
      }
    }
    return parts.isEmpty ? 'Nothing logged today' : parts.join(' · ');
  }

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);
}
