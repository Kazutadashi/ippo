// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module: daily yes/no habits, marked ✓ or ✗ each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'habit_log.dart';
import 'screens/habits_screen.dart';

/// The habits module, as seen by the core app.
class HabitsModule implements IppoModule {
  /// Creates the module.
  const HabitsModule();

  @override
  String get moduleName => habitsModuleName;

  @override
  String get title => 'Habits';

  @override
  IconData get icon => Icons.check_circle_outline;

  /// Two tiles: how many habits are done today, and which are left.
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final log = HabitLog.fromEvents(appState.eventLog?.events ?? []);
    final habits = log.shownHabits;
    final date = formatDate(now);
    if (habits.isEmpty) {
      return const [
        TodayFact(
          icon: Icons.check_circle_outline,
          label: 'Habits',
          value: TodayFact.unknownValue,
          detail: 'No habits yet',
        ),
        TodayFact(
          icon: Icons.radio_button_unchecked,
          label: 'To do',
          value: TodayFact.unknownValue,
          detail: 'No habits yet',
        ),
      ];
    }
    final done = habits
        .where((habit) => log.markOn(habit.id, date) == DayMark.done)
        .length;
    final open = habits
        .where((habit) => log.markOn(habit.id, date) == DayMark.none)
        .map((habit) => habit.name)
        .toList();
    return [
      TodayFact(
        icon: Icons.check_circle_outline,
        label: 'Habits',
        value: '$done / ${habits.length}',
        detail: 'done today',
      ),
      TodayFact(
        icon: Icons.radio_button_unchecked,
        label: 'To do',
        value: '${open.length}',
        detail: open.isEmpty ? 'All marked for today' : open.join(', '),
      ),
    ];
  }

  @override
  Widget buildScreen(AppState appState) => HabitsScreen(appState: appState);
}
