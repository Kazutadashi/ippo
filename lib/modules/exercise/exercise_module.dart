// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module: exercises and the sets done each day.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/widgets/dumbbell_icon.dart';
import 'exercise.dart';
import 'exercise_log.dart';
import 'screens/exercise_home_screen.dart';

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

  /// How many exercises were done on [day], with one mark each saying
  /// whether it beat its last session; then how many did (or when the
  /// last workout was), and the day's steps.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final log = ExerciseLog.of(appState);
    final exercises = log.activeExercises;
    final date = formatDate(day);
    final steps = log.stepsOn(date);
    final stepsLine = steps == null ? null : '${steps.steps} steps';
    if (exercises.isEmpty) {
      return HomeTile(
        value: HomeTile.unknownValue,
        lines: ['No exercises yet', if (stepsLine != null) stepsLine],
      );
    }
    final progress = [
      for (final exercise in exercises) _progressOf(log, exercise, date),
    ];
    final done = progress.where((one) => one != _Progress.notDone).length;
    final beat = progress.where((one) => one == _Progress.better).length;
    final trainedDays = daysBefore(day)
        .where((before) => _trainedOn(log, formatDate(before)))
        .length;
    return HomeTile(
      value: '$done of ${exercises.length}',
      valueNote: 'done',
      mark: _ProgressMarks(exercises: exercises, progress: progress),
      lines: [
        if (done == 0)
          _sinceLastWorkout(log, day, isToday: day == currentDay(now))
        else
          '$beat beat last time',
        // The day's steps when logged; otherwise the week's workouts.
        stepsLine ?? 'Trained $trainedDays of the last 7 days',
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
}

/// A note for a day without sets: when the last workout before it was,
/// such as "Last workout 2 days ago" (or "… before", looking back at an
/// earlier day), or that there is none yet.
String _sinceLastWorkout(
  ExerciseLog log,
  DateTime day, {
  required bool isToday,
}) {
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
    return 'No sets logged yet';
  }
  final days = day.difference(last).inDays;
  if (days == 1) {
    return isToday ? 'Last workout yesterday' : 'Last workout the day before';
  }
  return 'Last workout $days days ${isToday ? 'ago' : 'before'}';
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

/// How an exercise went on a day, compared with its last session.
enum _Progress {
  /// Its best set beat the last session's best.
  better,

  /// The same best as last time.
  same,

  /// A lower best than last time.
  less,

  /// Done for the first time: nothing to compare with.
  first,

  /// Not done that day.
  notDone,
}

/// How [exercise] went on [date], by its best set against the best set
/// of the session before.
_Progress _progressOf(ExerciseLog log, Exercise exercise, String date) {
  final sets = log.setsOn(date, exercise.id);
  if (sets.isEmpty) {
    return _Progress.notDone;
  }
  final previous = log.previousSessionOf(exercise.id, date);
  if (previous == null || previous.sets.isEmpty) {
    return _Progress.first;
  }
  final best = sets.map((set) => set.value).reduce(max);
  final bestBefore = previous.sets.map((set) => set.value).reduce(max);
  if (best > bestBefore) {
    return _Progress.better;
  }
  return best == bestBefore ? _Progress.same : _Progress.less;
}

/// One mark per exercise, in the order of the Exercise tab: an arrow up
/// when it beat last time, a dash when it matched it, an arrow down when
/// it fell short, a dot when done for the first time, and a faint ring
/// when not done yet. Calm on purpose: a lower day is grey, never red.
class _ProgressMarks extends StatelessWidget {
  const _ProgressMarks({required this.exercises, required this.progress});

  final List<Exercise> exercises;
  final List<_Progress> progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const words = {
      _Progress.better: 'better than last time',
      _Progress.same: 'same as last time',
      _Progress.less: 'less than last time',
      _Progress.first: 'done',
      _Progress.notDone: 'not done',
    };
    return Semantics(
      label: [
        for (var index = 0; index < exercises.length; index++)
          '${exercises[index].name}: ${words[progress[index]]}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [for (final one in progress) _mark(one, colors)],
        ),
      ),
    );
  }

  Widget _mark(_Progress progress, ColorScheme colors) {
    final accent = colors.primary;
    final muted = colors.onSurfaceVariant;
    return SizedBox(
      width: 18,
      height: 18,
      child: switch (progress) {
        _Progress.better => Icon(Icons.arrow_upward, size: 18, color: accent),
        _Progress.same => Icon(Icons.remove, size: 18, color: muted),
        _Progress.less => Icon(Icons.arrow_downward, size: 18, color: muted),
        _Progress.first => Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ),
        _Progress.notDone => Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
          ),
        ),
      },
    );
  }
}
