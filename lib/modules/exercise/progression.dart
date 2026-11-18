// SPDX-License-Identifier: GPL-3.0-or-later

/// A progression: an ordered ladder of exercises, easiest first.
library;

import '../../core/events/things.dart';
import 'exercise.dart';

/// One step of a progression: an exercise and the target to reach before
/// moving up.
class ProgressionStep {
  /// Creates a step.
  const ProgressionStep({
    required this.exerciseId,
    required this.targetSets,
    required this.targetPerSet,
    required this.measuredIn,
  });

  /// Reads a step from event data. Returns null if it is not valid.
  ///
  /// The target per set is stored as `target_reps` or `target_seconds`;
  /// whichever is present says how the step is measured.
  static ProgressionStep? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final exerciseId = json['exercise_id'];
    final targetSets = json['target_sets'];
    final hasReps = json.containsKey('target_reps');
    final targetPerSet = hasReps ? json['target_reps'] : json['target_seconds'];
    if (exerciseId is! String) {
      return null;
    }
    if (targetSets is! int || targetSets < 1) {
      return null;
    }
    if (targetPerSet is! int || targetPerSet < 1) {
      return null;
    }
    return ProgressionStep(
      exerciseId: exerciseId,
      targetSets: targetSets,
      targetPerSet: targetPerSet,
      measuredIn: hasReps ? MeasuredIn.reps : MeasuredIn.seconds,
    );
  }

  /// Turns the step into event data, as in `docs/data-format.md`.
  Map<String, Object?> toJson() {
    return {
      'exercise_id': exerciseId,
      'target_sets': targetSets,
      if (measuredIn == MeasuredIn.reps) 'target_reps': targetPerSet,
      if (measuredIn == MeasuredIn.seconds) 'target_seconds': targetPerSet,
    };
  }

  /// The exercise for this step.
  final String exerciseId;

  /// How many sets must reach [targetPerSet].
  final int targetSets;

  /// The reps or seconds each of those sets must reach.
  final int targetPerSet;

  /// Whether [targetPerSet] counts reps or seconds. It matches the
  /// exercise's own [Exercise.measuredIn].
  final MeasuredIn measuredIn;

  /// Describes the target, for example `3 × 12 reps` or `3 × 30 s`.
  String describeTarget() => '$targetSets × $targetPerSet ${measuredIn.unit}';
}

/// A progression. Created by `progression_created`.
class Progression {
  /// Creates a progression.
  const Progression({
    required this.id,
    required this.name,
    required this.steps,
    required this.isDeleted,
  });

  /// Reads a progression from its collected events. Returns null if the
  /// data is not valid, including if any step is not valid.
  static Progression? fromRecord(ThingRecord record) {
    final name = record.fields['name'];
    final stepsJson = record.fields['steps'];
    if (name is! String || name.trim().isEmpty || stepsJson is! List) {
      return null;
    }
    final steps = <ProgressionStep>[];
    for (final stepJson in stepsJson) {
      final step = ProgressionStep.fromJson(stepJson);
      if (step == null) {
        return null;
      }
      steps.add(step);
    }
    if (steps.isEmpty) {
      return null;
    }
    return Progression(
      id: record.id,
      name: name,
      steps: steps,
      isDeleted: record.isDeleted,
    );
  }

  /// The progression's id.
  final String id;

  /// The progression's name, for example "Squat progression".
  final String name;

  /// The steps, easiest first. Never empty.
  final List<ProgressionStep> steps;

  /// Whether the progression was deleted.
  final bool isDeleted;

  /// The step with [stepNumber], counting from 1, kept within range.
  ProgressionStep stepAt(int stepNumber) {
    return steps[stepNumber.clamp(1, steps.length) - 1];
  }
}
