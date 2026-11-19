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
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    final date = formatDate(currentDay(now));
    if (habits.isEmpty) {
      return const [
        TodayFact(
          label: 'Habits',
          value: TodayFact.unknownValue,
          note: 'No habits yet',
        ),
        TodayFact(
          label: 'To do',
          value: TodayFact.unknownValue,
          note: 'No habits yet',
        ),
      ];
    }
    final done = habits
        .where((habit) => log.markOn(habit.id, date) == DayMark.done)
        .length;
    final open = [
      for (final habit in habits)
        if (log.markOn(habit.id, date) == DayMark.none) habit.name,
    ];
    return [
      TodayFact(
        label: 'Habits',
        value: '$done / ${habits.length}',
        note: 'done today',
      ),
      TodayFact(
        label: 'To do',
        value: open.isEmpty ? 'All marked' : '${open.length} left',
        note: open.isEmpty ? 'Every habit has a mark today.' : null,
        details: _openHabitLines(open),
      ),
    ];
  }

  @override
  Widget buildScreen(AppState appState) => HabitsScreen(appState: appState);
}

/// The names of the habits still open today, one per line. Two lines at
/// most: with more, the second line ends in "+ 2 more".
List<TileDetail> _openHabitLines(List<String> open) {
  if (open.length <= 2) {
    return [for (final name in open) TileDetail(name)];
  }
  return [
    TileDetail(open[0]),
    TileDetail('${open[1]} + ${open.length - 2} more'),
  ];
}
