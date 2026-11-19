// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module: daily yes/no habits, marked ✓ or ✗ each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'habit.dart';
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
  List<TodayFact> dayFacts(AppState appState, DateTime day, DateTime now) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    if (habits.isEmpty) {
      return const [
        TodayFact(
          label: 'Habits',
          value: TodayFact.unknownValue,
          note: 'No habits yet',
        ),
        TodayFact(
          label: 'Streaks',
          value: TodayFact.unknownValue,
          note: 'No habits yet',
        ),
      ];
    }
    final date = formatDate(day);
    final done = habits
        .where((habit) => log.markOn(habit.id, date) == DayMark.done)
        .length;
    final open = [
      for (final habit in habits)
        if (log.markOn(habit.id, date) == DayMark.none) habit.name,
    ];
    return [
      // How the day is going, and what is still open.
      TodayFact(
        label: 'Habits',
        value: '$done / ${habits.length}',
        note: open.isEmpty ? 'Every habit is marked.' : null,
        details: _openHabitLines(open),
      ),
      _streaksFact(log, habits, day),
    ];
  }

  @override
  TileDetail? weekSummary(AppState appState, DateTime day) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    if (habits.isEmpty) {
      return null;
    }
    var done = 0;
    for (var back = 0; back < 7; back++) {
      final date = formatDate(addDays(day, -back));
      for (final habit in habits) {
        if (log.markOn(habit.id, date) == DayMark.done) {
          done++;
        }
      }
    }
    final percent = (100 * done / (7 * habits.length)).round();
    return TileDetail('$percent %', label: 'Habits done');
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

/// The "Streaks" tile: the longest current streak, and which habit it
/// is, then the next longest.
TodayFact _streaksFact(HabitLog log, List<Habit> habits, DateTime day) {
  final streaks = [
    for (final habit in habits)
      (habit: habit, days: log.streakOn(habit.id, day)),
  ]..sort((first, second) => second.days.compareTo(first.days));
  final best = streaks.first;
  if (best.days == 0) {
    return const TodayFact(
      label: 'Streaks',
      value: TodayFact.unknownValue,
      note: 'No streak right now.',
    );
  }
  final second = streaks.length > 1 && streaks[1].days > 0 ? streaks[1] : null;
  return TodayFact(
    label: 'Streaks',
    value: _days(best.days),
    details: [
      TileDetail(best.habit.name),
      if (second != null)
        TileDetail('${second.habit.name}: ${_days(second.days)}'),
    ],
  );
}

/// `1 day` or `12 days`.
String _days(int count) => count == 1 ? '1 day' : '$count days';
