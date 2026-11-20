// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module: daily yes/no habits, marked ✓ or ✗ each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import 'habit.dart';
import 'habit_log.dart';
import 'habit_marks.dart';
import 'screens/habits_screen.dart';
import 'habits_demo.dart';

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

  /// How many habits are done on [day], with one dot per habit; then the
  /// best streak of any habit, and how many were done a day on average
  /// over the week before.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    if (habits.isEmpty) {
      return const HomeTile(
        value: HomeTile.unknownValue,
        note: 'No habits yet',
      );
    }
    final date = formatDate(day);
    final streak = _longestStreak(log, habits, day);
    final average = _averageDone(log, habits, day);
    return HomeTile(
      value: '${_doneOn(log, habits, date)} of ${habits.length}',
      valueNote: 'done',
      mark: HabitDots(habits: habits, log: log, date: date),
      rows: [
        // The longest run of days in a row of any habit; one day is not a
        // run yet.
        if (streak.days >= 2) TileRow('Best streak', '${streak.days} days'),
        if (average != null)
          TileRow(
            'Avg (7 days)',
            '${formatAmount(average)} of ${habits.length}',
          ),
      ],
    );
  }

  /// The percentage of habits done on each of the seven days; a day
  /// with nothing marked shows as empty.
  @override
  List<WeekRow> weekRows(AppState appState, DateTime day) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    if (habits.isEmpty) {
      return const [];
    }
    final cells = <String?>[];
    for (final column in weekEndingOn(day)) {
      final date = formatDate(column);
      final anyMarked = habits.any(
        (habit) => log.markOn(habit.id, date) != DayMark.none,
      );
      final percent = (100 * _doneOn(log, habits, date) / habits.length)
          .round();
      cells.add(anyMarked ? '$percent' : null);
    }
    return [
      WeekRow(
        label: 'Habits (%)',
        cells: cells,
        description: 'Percentage of habits done each day',
      ),
    ];
  }

  /// Days with any habit marked, done or not.
  @override
  Set<String> datesLogged(AppState appState) => {
    for (final entry in HabitLog.of(appState).entries)
      if (!entry.isDeleted) entry.date,
  };

  @override
  Widget buildScreen(AppState appState) => HabitsScreen(appState: appState);

  /// The share of habits done, on days with any habit marked.
  @override
  List<TrendMeasure> trendMeasures(AppState appState) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    if (habits.isEmpty) {
      return const [];
    }
    return [
      TrendMeasure(
        label: 'Habits done',
        valueOn: (date) {
          final anyMarked = habits.any(
            (habit) => log.markOn(habit.id, date) != DayMark.none,
          );
          return anyMarked
              ? 100 * _doneOn(log, habits, date) / habits.length
              : null;
        },
        format: (percent) => '${percent.round()} %',
      ),
    ];
  }

  @override
  List<DemoEvent> demoEvents(DemoPlan plan) => habitsDemoEvents(plan);
}

/// How many of [habits] are done on [date] (`YYYY-MM-DD`).
int _doneOn(HabitLog log, List<Habit> habits, String date) =>
    habits.where((habit) => log.markOn(habit.id, date) == DayMark.done).length;

/// The average number of [habits] done a day over the week before
/// [day], counting only days with any habit marked; null without any.
double? _averageDone(HabitLog log, List<Habit> habits, DateTime day) {
  var done = 0;
  var markedDays = 0;
  for (final before in daysBefore(day)) {
    final date = formatDate(before);
    final anyMarked = habits.any(
      (habit) => log.markOn(habit.id, date) != DayMark.none,
    );
    if (anyMarked) {
      done += _doneOn(log, habits, date);
      markedDays++;
    }
  }
  return markedDays == 0 ? null : done / markedDays;
}

/// The habit with the longest current streak on [day], and its length.
({Habit habit, int days}) _longestStreak(
  HabitLog log,
  List<Habit> habits,
  DateTime day,
) {
  var best = (habit: habits.first, days: log.streakOn(habits.first.id, day));
  for (final habit in habits.skip(1)) {
    final days = log.streakOn(habit.id, day);
    if (days > best.days) {
      best = (habit: habit, days: days);
    }
  }
  return best;
}
