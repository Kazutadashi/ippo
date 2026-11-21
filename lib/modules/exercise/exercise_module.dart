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
    final done = log.activeExercises
        .where((exercise) => log.setsOn(date, exercise.id).isNotEmpty)
        .length;
    final averageSteps = _averageSteps(log, day);
    return HomeTile(
      value: steps == null
          ? HomeTile.unknownValue
          : formatThousands(steps.steps),
      valueNote: steps == null ? 'No steps yet' : 'steps',
      // The week at a glance: which of the last seven days had a
      // workout. Nothing is planned, so a day without one is simply that.
      mark: _WorkoutWeek(
        days: weekEndingOn(day),
        trained: {
          for (final weekDay in weekEndingOn(day))
            if (_trainedOn(log, formatDate(weekDay))) weekDay,
        },
        shown: day,
      ),
      rows: [
        if (done > 0)
          TileRow(
            isToday ? 'Today' : 'This day',
            '$done ${done == 1 ? 'exercise' : 'exercises'}',
          )
        else
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

/// Whether any exercise has a set on [date].
bool _trainedOn(ExerciseLog log, String date) => log.activeExercises.any(
  (exercise) => log.setsOn(date, exercise.id).isNotEmpty,
);

/// The last seven days as a bar of seven segments, the day shown last:
/// filled on a day with a workout, an outline on a day without. Under
/// it, each day's letter, the day shown in the accent colour. The same
/// look as the habits bar: filled is done, outlined is not.
class _WorkoutWeek extends StatelessWidget {
  const _WorkoutWeek({
    required this.days,
    required this.trained,
    required this.shown,
  });

  /// The seven days, oldest first.
  final List<DateTime> days;

  /// Those with a workout.
  final Set<DateTime> trained;

  /// The day shown on Home, the last of them.
  final DateTime shown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Semantics(
      label:
          'Workouts in the last 7 days: ${trained.length} '
          '${trained.length == 1 ? 'day' : 'days'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final (index, day) in days.indexed) ...[
                  if (index > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: trained.contains(day) ? colors.primary : null,
                        border: trained.contains(day)
                            ? null
                            : Border.all(
                                color: colors.primary.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                for (final (index, day) in days.indexed) ...[
                  if (index > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      letters[day.weekday - 1],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: day == shown
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: day == shown ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
