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
import 'habits_demo.dart';
import 'habit_order.dart';

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
    final habits = habitsInOrder(appState, log);
    if (habits.isEmpty) {
      return const HomeTile(
        value: HomeTile.unknownValue,
        note: 'No habits yet',
      );
    }
    final date = formatDate(day);
    final streak = _longestStreak(log, habits, day);
    final average = _averagePercent(log, habits, day);
    return HomeTile(
      // Of the habits that count today: due, or done anyway. A habit
      // waiting for its next turn is not "not done".
      value:
          '${_doneOn(log, habits, date)} of ${_countingOn(log, habits, date)}',
      valueNote: 'done',
      mark: HabitBar(habits: habits, log: log, date: date),
      rows: [
        // The longest run of days in a row of any habit; one day is not a
        // run yet.
        if (streak.days >= 2) TileRow('Best streak', '${streak.days} days'),
        if (average != null)
          TileRow('Avg (7 days)', '${average.round()} % done'),
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
      final percent = _percentOn(log, habits, date);
      cells.add(anyMarked && percent != null ? '${percent.round()}' : null);
    }
    return [
      WeekRow(
        label: 'Habits (%)',
        cells: cells,
        description: 'Percentage of the day\'s due habits done each day',
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
        valueOn: (date) => _percentIfMarked(log, habits, date),
        format: (percent) => '${percent.round()} %',
      ),
    ];
  }

  /// The share of habits done each day any habit was marked.
  @override
  List<ChartSpec> charts(AppState appState) {
    final log = HabitLog.of(appState);
    final habits = log.shownHabits;
    final dates = datesLogged(appState);
    if (habits.isEmpty || dates.isEmpty) {
      return const [];
    }
    return [
      ChartSpec(
        title: 'Habits done',
        unit: '%',
        values: dailyValues(
          dates,
          (date) => _percentIfMarked(log, habits, date),
        ),
        format: (percent) => '${percent.round()} %',
        fixedMin: 0,
        fixedMax: 100,
        // Habits are ticked through the day: today is not done yet.
        isRunningTotal: true,
      ),
    ];
  }

  @override
  List<DemoEvent> demoEvents(DemoPlan plan) => habitsDemoEvents(plan);
}

/// The share of [habits] done on [date] (see [_percentOn]), or null on a
/// day with no habit marked at all: a day nobody looked at the habits is
/// not a day of none done.
double? _percentIfMarked(HabitLog log, List<Habit> habits, String date) {
  final anyMarked = habits.any(
    (habit) => log.markOn(habit.id, date) != DayMark.none,
  );
  return anyMarked ? _percentOn(log, habits, date) : null;
}

/// How many of [habits] are done on [date] (`YYYY-MM-DD`).
int _doneOn(HabitLog log, List<Habit> habits, String date) =>
    habits.where((habit) => log.markOn(habit.id, date) == DayMark.done).length;

/// How many of [habits] count on [date]: those due that day, and any
/// done although not due. A habit waiting for its next turn does not
/// count, so it never looks missed.
int _countingOn(HabitLog log, List<Habit> habits, String date) => habits
    .where(
      (habit) =>
          log.isDueOn(habit, date) ||
          log.markOn(habit.id, date) == DayMark.done,
    )
    .length;

/// The share of the habits that count on [date] (see [_countingOn])
/// that were done, from 0 to 100; null when none count.
double? _percentOn(HabitLog log, List<Habit> habits, String date) {
  final counting = _countingOn(log, habits, date);
  return counting == 0 ? null : 100 * _doneOn(log, habits, date) / counting;
}

/// The average share of habits done a day over the week before [day]
/// (see [_percentOn]), counting only days with any habit marked; null
/// without any.
double? _averagePercent(HabitLog log, List<Habit> habits, DateTime day) {
  final percents = <double>[];
  for (final before in daysBefore(day)) {
    final date = formatDate(before);
    final anyMarked = habits.any(
      (habit) => log.markOn(habit.id, date) != DayMark.none,
    );
    final percent = _percentOn(log, habits, date);
    if (anyMarked && percent != null) {
      percents.add(percent);
    }
  }
  if (percents.isEmpty) {
    return null;
  }
  return percents.reduce((a, b) => a + b) / percents.length;
}

/// The habit with the longest current streak on [day], and its length.
({Habit habit, int days}) _longestStreak(
  HabitLog log,
  List<Habit> habits,
  DateTime day,
) {
  var best = (habit: habits.first, days: log.streakOn(habits.first, day));
  for (final habit in habits.skip(1)) {
    final days = log.streakOn(habit, day);
    if (days > best.days) {
      best = (habit: habit, days: days);
    }
  }
  return best;
}
