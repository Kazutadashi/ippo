// SPDX-License-Identifier: GPL-3.0-or-later

/// Saving changes in the exercise module, as events.
///
/// Every change the exercise screens make goes through this class, so
/// the event types and fields written are all in one place. They follow
/// `docs/data-format.md`, section "Module: exercise".
library;

import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/number_input.dart';
import 'exercise.dart';
import 'exercise_log.dart';
import 'exercise_set.dart';
import 'progression.dart';

/// Writes the exercise module's events through [appState].
///
/// Every method throws `DataFolderException` if the event cannot be
/// saved; nothing is saved then.
class ExerciseActions {
  /// Creates the actions for [appState].
  ExerciseActions(this.appState);

  /// The app state that writes the events.
  final AppState appState;

  /// Creates an exercise. Returns the event, whose id is the exercise's.
  Future<Event> createExercise({
    required String name,
    required MeasuredIn measuredIn,
  }) {
    return _write('exercise_created', {
      'name': name.trim(),
      'measured_in': measuredIn.name,
    });
  }

  /// Renames an exercise.
  Future<Event> renameExercise(String exerciseId, String newName) {
    return _write('exercise_changed', {
      'target_id': exerciseId,
      'changes': {'name': newName.trim()},
    });
  }

  /// Deletes an exercise. Its past sets stay.
  Future<Event> deleteExercise(String exerciseId) =>
      _write('exercise_deleted', {'target_id': exerciseId});

  /// Undoes [deleteExercise].
  Future<Event> restoreExercise(String exerciseId) =>
      _write('exercise_restored', {'target_id': exerciseId});

  /// Creates a progression. Returns the event, whose id is the
  /// progression's.
  Future<Event> createProgression({
    required String name,
    required List<ProgressionStep> steps,
  }) {
    return _write('progression_created', {
      'name': name.trim(),
      'steps': [for (final step in steps) step.toJson()],
    });
  }

  /// Changes a progression's name and replaces its whole list of steps.
  Future<Event> changeProgression(
    String progressionId, {
    required String name,
    required List<ProgressionStep> steps,
  }) {
    return _write('progression_changed', {
      'target_id': progressionId,
      'changes': {
        'name': name.trim(),
        'steps': [for (final step in steps) step.toJson()],
      },
    });
  }

  /// Saves a progression from the steps typed in the progression form.
  ///
  /// Each step names its exercise. A step without an exercise id gets
  /// one: an existing exercise with the same name and unit is reused (so
  /// its history stays in one place), otherwise a new exercise is
  /// created. A step whose exercise name was edited renames that
  /// exercise. Then the progression is created, or changed if
  /// [progressionId] is given. Returns the progression's id.
  Future<String> saveProgressionFromDrafts({
    required String? progressionId,
    required String name,
    required List<StepDraft> drafts,
    required ExerciseLog log,
  }) async {
    final steps = <ProgressionStep>[];
    for (final draft in drafts) {
      final exerciseId = await _exerciseIdFor(draft, log);
      steps.add(
        ProgressionStep(
          exerciseId: exerciseId,
          targetSets: draft.targetSets,
          targetPerSet: draft.targetPerSet,
          measuredIn: draft.measuredIn,
        ),
      );
    }
    if (progressionId == null) {
      final event = await createProgression(name: name, steps: steps);
      return event.id;
    }
    await changeProgression(progressionId, name: name, steps: steps);
    return progressionId;
  }

  /// Finds or creates the exercise for one step of the progression form.
  Future<String> _exerciseIdFor(StepDraft draft, ExerciseLog log) async {
    final draftName = draft.exerciseName.trim();
    final existingId = draft.exerciseId;
    if (existingId != null) {
      final existing = log.exercises[existingId];
      if (existing != null && existing.name != draftName) {
        await renameExercise(existingId, draftName);
      }
      return existingId;
    }
    for (final exercise in log.exercises.values) {
      final isSameExercise =
          !exercise.isDeleted &&
          exercise.measuredIn == draft.measuredIn &&
          exercise.name.toLowerCase() == draftName.toLowerCase();
      if (isSameExercise) {
        return exercise.id;
      }
    }
    final event = await createExercise(
      name: draftName,
      measuredIn: draft.measuredIn,
    );
    return event.id;
  }

  /// Deletes a progression. Its past sets stay.
  Future<Event> deleteProgression(String progressionId) =>
      _write('progression_deleted', {'target_id': progressionId});

  /// Undoes [deleteProgression].
  Future<Event> restoreProgression(String progressionId) =>
      _write('progression_restored', {'target_id': progressionId});

  /// Records that the user is now on [stepNumber] of a progression.
  Future<Event> setProgressionStep(
    String progressionId, {
    required int stepNumber,
    required String date,
  }) {
    return _write('progression_step_set', {
      'progression_id': progressionId,
      'step_number': stepNumber,
      'date': date,
    });
  }

  /// Records one set of [exercise] on [date].
  ///
  /// [value] is reps or seconds, depending on the exercise. If the set is
  /// part of [progression], the current step and its target are copied
  /// into the set, so history stays correct if the progression changes.
  /// [setNumber] counts the sets of this exercise on this day, from 1.
  Future<Event> recordSet({
    required String date,
    required Exercise exercise,
    required int setNumber,
    required int value,
    required double? weightKg,
    required int? repsInReserve,
    required Progression? progression,
    required int? stepNumber,
  }) {
    final step = progression != null && stepNumber != null
        ? progression.stepAt(stepNumber)
        : null;
    return _write('set_recorded', {
      'exercise_id': exercise.id,
      'date': date,
      'set_number': setNumber,
      _valueField(exercise.measuredIn): value,
      if (weightKg != null) 'weight_kg': jsonNumber(weightKg),
      if (repsInReserve != null) 'reps_in_reserve': repsInReserve,
      if (progression != null) 'progression_id': progression.id,
      if (step != null) 'step_number': stepNumber,
      if (step != null) _targetField(step.measuredIn): step.targetPerSet,
    });
  }

  /// Changes the value, weight and effort of a set. A null [weightKg] or
  /// [repsInReserve] clears that value.
  Future<Event> changeSet(
    ExerciseSet set, {
    required MeasuredIn measuredIn,
    required int value,
    required double? weightKg,
    required int? repsInReserve,
  }) {
    return _write('set_changed', {
      'target_id': set.id,
      'changes': {
        _valueField(measuredIn): value,
        'weight_kg': weightKg == null ? null : jsonNumber(weightKg),
        'reps_in_reserve': repsInReserve,
      },
    });
  }

  /// Deletes a set.
  Future<Event> deleteSet(String setId) =>
      _write('set_deleted', {'target_id': setId});

  /// Undoes [deleteSet].
  Future<Event> restoreSet(String setId) =>
      _write('set_restored', {'target_id': setId});

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(
      module: exerciseModuleName,
      type: type,
      data: data,
    );
  }
}

/// The field a set's value is stored in: `reps` or `seconds`.
String _valueField(MeasuredIn measuredIn) =>
    measuredIn == MeasuredIn.reps ? 'reps' : 'seconds';

/// The field a step's target is stored in.
String _targetField(MeasuredIn measuredIn) =>
    measuredIn == MeasuredIn.reps ? 'target_reps' : 'target_seconds';

/// One step as typed in the progression form, before it is saved.
class StepDraft {
  /// Creates a step draft.
  const StepDraft({
    required this.exerciseId,
    required this.exerciseName,
    required this.measuredIn,
    required this.targetSets,
    required this.targetPerSet,
  });

  /// The exercise's id, or null for an exercise not saved yet.
  final String? exerciseId;

  /// The exercise's name.
  final String exerciseName;

  /// Whether the exercise counts reps or seconds.
  final MeasuredIn measuredIn;

  /// How many sets must reach the target.
  final int targetSets;

  /// The reps or seconds each set must reach.
  final int targetPerSet;

  /// Describes the step, for example `Box squat — 3 × 12 reps`.
  String describe() =>
      '$exerciseName — $targetSets × $targetPerSet ${measuredIn.unit}';
}
