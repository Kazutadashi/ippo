// SPDX-License-Identifier: GPL-3.0-or-later

/// The list of modules the app shows.
///
/// This is the only place that knows every module. To add a module,
/// create its folder in `lib/modules/` and add it to this list; nothing
/// else needs to change.
library;

import '../core/app_state.dart';
import '../core/demo/demo_plan.dart';
import '../core/module.dart';
import 'exercise/exercise_module.dart';
import 'food/food_module.dart';
import 'habits/habits_module.dart';
import 'sleep/sleep_module.dart';

/// Every module, in the order shown on the home screen.
const List<IppoModule> allModules = [
  HabitsModule(),
  FoodModule(),
  ExerciseModule(),
  SleepModule(),
];

/// The demo's made-up events from every module, as one event file,
/// ending at [now]. See `demo_plan.dart`.
String demoEventFileForAllModules(DateTime now) {
  final plan = DemoPlan(now: now);
  return demoEventFile([
    for (final module in allModules) ...module.demoEvents(plan),
  ], now: now);
}

/// Starts the demo with every module's made-up data, ending now.
Future<void> startDemo(AppState appState) {
  return appState.startDemo(demoEventFileForAllModules(DateTime.now()));
}
