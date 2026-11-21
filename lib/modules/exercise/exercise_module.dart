// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: exercises and the sets done each day.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import '../../core/widgets/dumbbell_icon.dart';
import 'exercise_log.dart';
import 'screens/exercise_home_screen.dart';
import 'exercise_charts.dart';
import 'exercise_demo.dart';

/// The exercise module, as seen by the core app.
class ExerciseModule extends IppoModule {
  /// Creates the module.
  const ExerciseModule();

  @override
  String get moduleName => exerciseModuleName;

  @override
  String get title => 'Exercise';

  @override
  IconData get icon => Icons.fitness_center;

  /// A dumbbell with thick plates, drawn by hand: Material's has thin
  /// ones and stands at an angle.
  @override
  Widget buildIcon() => const DumbbellIcon();

  /// The steps walked on [day], the number most worth a glance; a badge
  /// saying whether there was a workout ("4 exercises today" or "Rest
  /// day"); then the daily average of steps and how many of the week's
  /// days had a workout.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final log = ExerciseLog.of(appState);
    final date = formatDate(day);
    final steps = log.stepsOn(date);
    final isToday = day == currentDay(now);
    final averageSteps = _averageSteps(log, day);
    // Each exercise done on the day, in the order they were added.
    final doneToday = [
      for (final exercise in log.activeExercises)
        if (log.setsOn(date, exercise.id).isNotEmpty) exercise.name,
    ];
    return HomeTile(
      value: steps == null
          ? HomeTile.unknownValue
          : formatThousands(steps.steps),
      valueNote: steps == null ? 'No steps yet' : 'steps',
      // One chip per exercise done: each means one exercise. A day
      // without says so instead.
      mark: doneToday.isEmpty ? null : _ExerciseChips(names: doneToday),
      note: doneToday.isEmpty
          ? (isToday ? 'No workout yet today' : 'No workout this day')
          : null,
      rows: [
        if (doneToday.isEmpty)
          TileRow('Last workout', _lastWorkout(log, day, isToday: isToday)),
        if (averageSteps != null)
          TileRow('Avg (7 days)', '${formatThousands(averageSteps)} steps'),
      ],
    );
  }

  /// Two rows: how many exercises were done each day, and the steps
  /// walked, in thousands to fit ("8.4").
  @override
  List<WeekRow> weekRows(AppState appState, DateTime day) {
    final log = ExerciseLog.of(appState);
    final columns = weekEndingOn(day);
    return [
      if (log.activeExercises.isNotEmpty)
        WeekRow(
          label: 'Exercises',
          cells: [
            for (final column in columns)
              _exercisesDone(log, formatDate(column)),
          ],
          description: 'Exercises done each day',
        ),
      if (log.steps.any((count) => !count.isDeleted))
        WeekRow(
          label: 'Steps (k)',
          cells: [
            for (final column in columns)
              _thousands(log.stepsOn(formatDate(column))?.steps),
          ],
          description: 'Steps walked each day, in thousands',
        ),
    ];
  }

  /// Days with any set or steps logged.
  @override
  Set<String> datesLogged(AppState appState) {
    final log = ExerciseLog.of(appState);
    return {
      for (final set in log.sets)
        if (!set.isDeleted) set.date,
      for (final count in log.steps)
        if (!count.isDeleted) count.date,
    };
  }

  @override
  Widget buildScreen(AppState appState) =>
      ExerciseHomeScreen(appState: appState);

  /// Workout days a week (from the first day with a set) and steps, on
  /// days with steps typed in.
  @override
  List<TrendMeasure> trendMeasures(AppState appState) {
    final log = ExerciseLog.of(appState);
    final workoutDates = {
      for (final set in log.sets)
        if (!set.isDeleted) set.date,
    };
    // Before the first workout ever, a day without one says nothing.
    final firstWorkout = workoutDates.isEmpty
        ? null
        : workoutDates.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    return [
      if (firstWorkout != null)
        TrendMeasure(
          label: 'Workouts',
          valueOn: (date) => date.compareTo(firstWorkout) < 0
              ? null
              : (workoutDates.contains(date) ? 1 : 0),
          format: (days) {
            final shown = roundToTenth(days);
            return '${formatAmount(shown)} ${shown == 1 ? 'day' : 'days'}';
          },
          isPerWeek: true,
        ),
      if (log.steps.any((count) => !count.isDeleted))
        TrendMeasure(
          label: 'Steps',
          valueOn: (date) => log.stepsOn(date)?.steps.toDouble(),
          format: (steps) => formatThousands(steps.round()),
        ),
    ];
  }

  @override
  List<ChartSpec> charts(AppState appState) => exerciseCharts(appState);

  @override
  List<DemoEvent> demoEvents(DemoPlan plan) => exerciseDemoEvents(plan);
}

/// When the last workout before [day] was: "yesterday" (or "the day
/// before" looking back), "3 days ago", or "none yet".
String _lastWorkout(ExerciseLog log, DateTime day, {required bool isToday}) {
  DateTime? last;
  for (final set in log.sets) {
    final setDay = parseDate(set.date);
    if (set.isDeleted || setDay == null || !setDay.isBefore(day)) {
      continue;
    }
    if (last == null || setDay.isAfter(last)) {
      last = setDay;
    }
  }
  if (last == null) {
    return 'none yet';
  }
  final days = day.difference(last).inDays;
  if (days == 1) {
    return isToday ? 'yesterday' : 'the day before';
  }
  return '$days days ${isToday ? 'ago' : 'before'}';
}

/// The average steps a day over the week before [day], counting only
/// days with steps logged; null without any.
int? _averageSteps(ExerciseLog log, DateTime day) {
  var total = 0;
  var days = 0;
  for (final before in daysBefore(day)) {
    final count = log.stepsOn(formatDate(before));
    if (count != null) {
      total += count.steps;
      days++;
    }
  }
  return days == 0 ? null : (total / days).round();
}

/// How many exercises have sets on [date], or null for none.
String? _exercisesDone(ExerciseLog log, String date) {
  final done = log.activeExercises
      .where((exercise) => log.setsOn(date, exercise.id).isNotEmpty)
      .length;
  return done == 0 ? null : '$done';
}

/// [steps] in thousands to one decimal, `8.4`, or null for none.
String? _thousands(int? steps) =>
    steps == null ? null : (steps / 1000).toStringAsFixed(1);

/// The day's exercises as small chips in a fixed grid of two rows of
/// two, so the tile keeps its height however many there are. Each chip
/// is one exercise done, its name shortened with "…" if it is long;
/// with more than four, the fourth chip says how many more ("+4 more").
/// How many sets each had is on the Exercise tab.
class _ExerciseChips extends StatelessWidget {
  const _ExerciseChips({required this.names});

  /// The names of the exercises done, in order.
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Four places: all names if they fit, else three and "+N more".
    final cells = names.length <= 4
        ? names
        : [...names.take(3), '+${names.length - 3} more'];
    return Semantics(
      label: 'Exercises done: ${names.join(', ')}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var row = 0; row * 2 < cells.length; row++) ...[
              if (row > 0) const SizedBox(height: 4),
              Row(
                children: [
                  for (var column = 0; column < 2; column++) ...[
                    if (column > 0) const SizedBox(width: 4),
                    Expanded(
                      child: row * 2 + column < cells.length
                          ? _chip(theme, cells[row * 2 + column])
                          // An empty place, so a lone chip is as wide as
                          // the others.
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One chip holding [text], on one line.
  Widget _chip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // The accent tint of logged things, as elsewhere.
        color: theme.chipTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
