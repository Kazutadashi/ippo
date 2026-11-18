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

  /// Records one set of [exercise] on [date].
  ///
  /// [value] is reps or seconds, depending on the exercise. [setNumber]
  /// counts the sets of this exercise on this day, from 1.
  Future<Event> recordSet({
    required String date,
    required Exercise exercise,
    required int setNumber,
    required int value,
  }) {
    return _write('set_recorded', {
      'exercise_id': exercise.id,
      'date': date,
      'set_number': setNumber,
      _valueField(exercise.measuredIn): value,
    });
  }

  /// Records [setCount] sets of [value] reps (or seconds) of [exercise]
  /// on [date], numbered after the sets already logged that day.
  ///
  /// [log] must be the current exercise log, used to count those sets.
  Future<void> recordSets({
    required String date,
    required Exercise exercise,
    required int value,
    required int setCount,
    required ExerciseLog log,
  }) async {
    final setsSoFar = log.setsOn(date, exercise.id).length;
    for (var count = 1; count <= setCount; count++) {
      await recordSet(
        date: date,
        exercise: exercise,
        setNumber: setsSoFar + count,
        value: value,
      );
    }
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
