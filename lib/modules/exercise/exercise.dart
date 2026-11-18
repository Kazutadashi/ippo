// SPDX-License-Identifier: GPL-3.0-or-later

/// One exercise, such as "Box squat" or "Plank".
library;

import '../../core/events/things.dart';

/// What an exercise is measured in. The names are stored in the data
/// and must never change.
enum MeasuredIn {
  /// Counted in repetitions.
  reps('reps'),

  /// Held for a number of seconds, such as a plank.
  seconds('s');

  const MeasuredIn(this.unit);

  /// The short unit shown after a number, for example `12 reps`.
  final String unit;

  /// Finds the value stored as [name], or null if there is none.
  static MeasuredIn? fromName(Object? name) {
    for (final value in MeasuredIn.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}

/// The longest name allowed for an exercise or progression.
const int maximumExerciseNameLength = 100;

/// An exercise. Created by `exercise_created`; see "Module: exercise" in
/// `docs/data-format.md`.
class Exercise {
  /// Creates an exercise.
  const Exercise({
    required this.id,
    required this.name,
    required this.measuredIn,
    required this.description,
    required this.isDeleted,
  });

  /// Reads an exercise from its collected events. Returns null if the
  /// data is not a valid exercise.
  static Exercise? fromRecord(ThingRecord record) {
    final name = record.fields['name'];
    final measuredIn = MeasuredIn.fromName(record.fields['measured_in']);
    final description = record.fields['description'];
    if (name is! String || name.trim().isEmpty || measuredIn == null) {
      return null;
    }
    return Exercise(
      id: record.id,
      name: name,
      measuredIn: measuredIn,
      description: description is String ? description : null,
      isDeleted: record.isDeleted,
    );
  }

  /// The exercise's id.
  final String id;

  /// The exercise's name.
  final String name;

  /// Whether sets are counted in reps or seconds. Never changes.
  final MeasuredIn measuredIn;

  /// Notes, for example on form.
  final String? description;

  /// Whether the exercise was deleted. Its past sets stay.
  final bool isDeleted;
}

/// Checks a name the user typed for an exercise or progression. Returns
/// null if it is fine, or a message explaining what is wrong.
String? checkExerciseName(String name) {
  if (name.trim().isEmpty) {
    return 'Please enter a name.';
  }
  if (name.trim().length > maximumExerciseNameLength) {
    return 'Please use at most $maximumExerciseNameLength characters.';
  }
  return null;
}
