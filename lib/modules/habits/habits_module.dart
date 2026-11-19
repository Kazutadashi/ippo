// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module: daily yes/no habits, marked ✓ or ✗ each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'habit.dart';
import 'habit_log.dart';
import 'habit_marks.dart';
import 'screens/habits_screen.dart';

/// The habits module, as seen by the core app.
class HabitsModule extends IppoModule {
  /// Creates the module.
  const HabitsModule();

  @override
  String get moduleName => habitsModuleName;

  @override
  String get title => 'Habits';

  @override
  IconData get icon => Icons.check_circle_outline;

  @override
  Color get color => const Color(0xFF5E9E72); // sage green

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
    return [
      // How the day is going: one dot per habit, and what is still open.
      TodayFact(
        label: 'Habits',
        value: '$done of ${habits.length}',
        visual: HabitDots(habits: habits, log: log, date: date),
      ),
      _streaksFact(log, habits, day),
    ];
  }

  @override
  Widget? weekStrip(AppState appState, DateTime day) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    if (habits.isEmpty) {
      return null;
    }
    return HabitWeekStrip(habits: habits, log: log, day: day, baseColor: color);
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
    return TileDetail('$percent %', label: 'Habits');
  }

  @override
  Widget buildScreen(AppState appState) => HabitsScreen(appState: appState);
}

/// The "Streaks" tile: the longest current streak, which habit it is,
/// and that habit's last seven days.
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
  // The longest streak, which habit it is, and its last seven days.
  return TodayFact(
    label: 'Streaks',
    value: _days(best.days),
    valueNote: best.habit.name,
    visual: StreakSquares(habit: best.habit, log: log, day: day),
  );
}

/// `1 day` or `12 days`.
String _days(int count) => count == 1 ? '1 day' : '$count days';
