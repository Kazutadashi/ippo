// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: progressions, sets and progress over time.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
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

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);
}
