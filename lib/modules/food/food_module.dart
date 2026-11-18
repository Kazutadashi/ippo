// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
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
  String summarizeToday(AppState appState) {
    final diary = FoodDiary.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(DateTime.now());
    final entryCount = diary.entriesOn(today).length;
    if (entryCount == 0) {
      return 'Nothing logged today';
    }
    final energy = formatAmount(diary.totalOn(today).energyKcal);
    final entryWord = entryCount == 1 ? 'entry' : 'entries';
    return '$entryCount $entryWord · $energy kcal';
  }

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);
}
