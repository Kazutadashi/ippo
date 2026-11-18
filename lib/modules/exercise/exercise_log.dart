// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module's current state, worked out from the event log.
library;

import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'exercise.dart';
import 'exercise_set.dart';

/// The module's name in event files. Never change it.
const String exerciseModuleName = 'exercise';

/// All exercises and sets, with every change applied.
class ExerciseLog {
  /// Creates a log. Normal code uses [ExerciseLog.fromEvents].
  ExerciseLog({
    required this.exercises,
    required this.sets,
    required this.invalidCount,
  });

  /// Builds the log from the event log's events (oldest first).
  ///
  /// The data format also describes progressions (ladders of
  /// exercises). The app does not use them, so their events are ignored;
  /// exercises and sets made with them still load normally.
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

    return ExerciseLog(
      exercises: exercises,
      sets: sets,
      invalidCount: invalidCount,
    );
  }

  /// Every exercise by id, including deleted ones.
  final Map<String, Exercise> exercises;

  /// Every set, including deleted ones, in the order they were logged.
  final List<ExerciseSet> sets;

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
