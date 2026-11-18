// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/module.dart';
import 'food_diary.dart';
import 'screens/food_diary_screen.dart';

/// The food module, as seen by the core app.
class FoodModule implements IppoModule {
  /// Creates the module.
  const FoodModule();

  @override
  String get moduleName => foodModuleName;

  @override
  String get title => 'Food';

  @override
  IconData get icon => Icons.restaurant;

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);
}
