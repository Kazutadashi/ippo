// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module's current state, worked out from the event log.
library;

import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'exercise.dart';
import 'exercise_set.dart';
import 'step_count.dart';

/// The module's name in event files. Never change it.
const String exerciseModuleName = 'exercise';

/// All exercises and sets, with every change applied.
class ExerciseLog {
  /// Creates a log. Normal code uses [ExerciseLog.fromEvents].
  ExerciseLog({
    required this.exercises,
    required this.sets,
    required this.steps,
    required this.invalidCount,
  });

  /// The current state for [appState], worked out once per change of
  /// the data and shared by every screen (see `AppState.derived`).
  static ExerciseLog of(AppState appState) => appState.derived(
    'exercise_log',
    ExerciseLog.fromEvents,
    module: exerciseModuleName,
  );

  /// Builds the log from the event log's events (oldest first).
  factory ExerciseLog.fromEvents(List<Event> events) {
    var invalidCount = 0;

    final exercises = <String, Exercise>{};
    for (final record in _collect(events, 'exercise_created', 'exercise')) {
      final exercise = Exercise.fromRecord(record);
      if (exercise == null) {
        invalidCount++;
      } else {
        exercises[exercise.id] = exercise;
      }
    }

    final sets = <ExerciseSet>[];
    for (final record in _collect(events, 'set_recorded', 'set')) {
      final set = ExerciseSet.fromRecord(record);
      if (set == null) {
        invalidCount++;
      } else {
        sets.add(set);
      }
    }

    final steps = <StepCount>[];
    for (final record in _collect(events, 'steps_recorded', 'steps')) {
      final count = StepCount.fromRecord(record);
      if (count == null) {
        invalidCount++;
      } else {
        steps.add(count);
      }
    }

    return ExerciseLog(
      exercises: exercises,
      sets: sets,
      steps: steps,
      invalidCount: invalidCount,
    );
  }

  /// Every exercise by id, including deleted ones.
  final Map<String, Exercise> exercises;

  /// Every set, including deleted ones, in the order they were logged.
  final List<ExerciseSet> sets;

  /// Every step count, including deleted ones, in the order logged.
  final List<StepCount> steps;

  /// The steps on [date] (`YYYY-MM-DD`): the count logged last for that
  /// day that is not deleted, or null if none. (Normally there is one per
  /// day, changed in place; two can arrive from two devices.)
  StepCount? stepsOn(String date) => _latestSteps[date];

  /// The last count on each day that is not deleted. Built once, the
  /// first time it is needed (a later count for a day replaces an
  /// earlier one in the map, so the last one counts).
  late final Map<String, StepCount> _latestSteps = {
    for (final count in steps)
      if (!count.isDeleted) count.date: count,
  };

  /// How many things were skipped because their data was not valid.
  final int invalidCount;

  /// The exercises that are not deleted, in the order they were created.
  List<Exercise> get activeExercises =>
      exercises.values.where((exercise) => !exercise.isDeleted).toList();

  /// The sets of [exerciseId] on [date] that are not deleted, in the
  /// order they were logged.
  List<ExerciseSet> setsOn(String date, String exerciseId) {
    return sets
        .where(
          (set) =>
              set.date == date &&
              set.exerciseId == exerciseId &&
              !set.isDeleted,
        )
        .toList();
  }

  /// The last day before [date] (`YYYY-MM-DD`) with sets of [exerciseId],
  /// and those sets in the order they were logged: the session to
  /// compare with. Null if there is none.
  ({String date, List<ExerciseSet> sets})? previousSessionOf(
    String exerciseId,
    String date,
  ) {
    String? latest;
    for (final set in sets) {
      // Dates written as YYYY-MM-DD sort like the days they name.
      final isEarlier = set.date.compareTo(date) < 0;
      final isLater = latest == null || set.date.compareTo(latest) > 0;
      if (set.exerciseId == exerciseId &&
          !set.isDeleted &&
          isEarlier &&
          isLater) {
        latest = set.date;
      }
    }
    if (latest == null) {
      return null;
    }
    return (date: latest, sets: setsOn(latest, exerciseId));
  }

  /// The most recently logged set of [exerciseId], or null if none.
  ExerciseSet? lastSetOf(String exerciseId) {
    for (final set in sets.reversed) {
      if (set.exerciseId == exerciseId && !set.isDeleted) {
        return set;
      }
    }
    return null;
  }
}

/// Collects one kind of thing of this module.
Iterable<ThingRecord> _collect(
  List<Event> events,
  String createdType,
  String thingName,
) {
  return collectThings(
    events,
    module: exerciseModuleName,
    createdType: createdType,
    thingName: thingName,
  ).values;
}
