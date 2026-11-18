// SPDX-License-Identifier: GPL-3.0-or-later

/// One set of one exercise.
library;

import '../../core/dates.dart';
import '../../core/events/things.dart';

/// A set. Created by `set_recorded`; see "Module: exercise" in
/// `docs/data-format.md`.
///
/// The progression, step and target are copies made when the set was
/// logged, so later changes to the progression do not change history.
class ExerciseSet {
  /// Creates a set.
  const ExerciseSet({
    required this.id,
    required this.exerciseId,
    required this.date,
    required this.setNumber,
    required this.value,
    required this.weightKg,
    required this.repsInReserve,
    required this.progressionId,
    required this.stepNumber,
    required this.targetPerSet,
    required this.note,
    required this.isDeleted,
    required this.loggedAtUtc,
  });

  /// Reads a set from its collected events. Returns null if the data is
  /// not a valid set.
  static ExerciseSet? fromRecord(ThingRecord record) {
    final fields = record.fields;
    final exerciseId = fields['exercise_id'];
    final date = fields['date'];
    final setNumber = fields['set_number'];
    // A set holds reps or seconds, depending on the exercise.
    final value = fields['reps'] ?? fields['seconds'];
    if (exerciseId is! String || date is! String || !isValidDate(date)) {
      return null;
    }
    if (setNumber is! int || value is! int || value < 0) {
      return null;
    }

    final weightKg = fields['weight_kg'];
    final repsInReserve = fields['reps_in_reserve'];
    final progressionId = fields['progression_id'];
    final stepNumber = fields['step_number'];
    final targetPerSet = fields['target_reps'] ?? fields['target_seconds'];
    final note = fields['note'];
    return ExerciseSet(
      id: record.id,
      exerciseId: exerciseId,
      date: date,
      setNumber: setNumber,
      value: value,
      // Optional fields with the wrong type are treated as missing.
      weightKg: weightKg is num && weightKg >= 0 ? weightKg.toDouble() : null,
      repsInReserve: repsInReserve is int && repsInReserve >= 0
          ? repsInReserve
          : null,
      progressionId: progressionId is String ? progressionId : null,
      stepNumber: stepNumber is int && stepNumber >= 1 ? stepNumber : null,
      targetPerSet: targetPerSet is int && targetPerSet >= 1
          ? targetPerSet
          : null,
      note: note is String ? note : null,
      isDeleted: record.isDeleted,
      loggedAtUtc: record.createdAtUtc,
    );
  }

  /// The set's id.
  final String id;

  /// The exercise done.
  final String exerciseId;

  /// The day of the workout, `YYYY-MM-DD`.
  final String date;

  /// 1 for the first set of this exercise that day, 2 for the next, ...
  final int setNumber;

  /// Reps done, or seconds held, depending on the exercise.
  final int value;

  /// Added weight in kilograms, or null for body weight only.
  final double? weightKg;

  /// How many more reps could have been done, if recorded.
  final int? repsInReserve;

  /// The progression this set was part of, if any.
  final String? progressionId;

  /// The step of that progression at the time, if any.
  final int? stepNumber;

  /// The target reps or seconds per set at the time, if any.
  final int? targetPerSet;

  /// A note, if any.
  final String? note;

  /// Whether the set was deleted.
  final bool isDeleted;

  /// When the set was logged, in UTC.
  final DateTime loggedAtUtc;
}
