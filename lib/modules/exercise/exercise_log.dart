// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module's current state, worked out from the event log.
library;

import 'dart:math';

import '../../core/events/event.dart';
import '../../core/events/things.dart';
import '../../core/widgets/line_chart.dart';
import 'exercise.dart';
import 'exercise_set.dart';
import 'progress.dart';
import 'progression.dart';

/// The module's name in event files. Never change it.
const String exerciseModuleName = 'exercise';

/// One day's sets, for history lists.
class DaySets {
  /// Creates the sets of one day.
  const DaySets(this.date, this.sets);

  /// The day, `YYYY-MM-DD`.
  final String date;

  /// The sets on that day, in the order they were logged.
  final List<ExerciseSet> sets;
}

/// All exercises, progressions and sets, with every change applied.
class ExerciseLog {
  /// Creates a log. Normal code uses [ExerciseLog.fromEvents].
  ExerciseLog({
    required this.exercises,
    required this.progressions,
    required this.sets,
    required this.savedStepNumbers,
    required this.invalidCount,
  });

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

    final progressions = <String, Progression>{};
    for (final record in _collect(
      events,
      'progression_created',
      'progression',
    )) {
      final progression = Progression.fromRecord(record);
      if (progression == null) {
        invalidCount++;
      } else {
        progressions[progression.id] = progression;
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
      progressions: progressions,
      sets: sets,
      savedStepNumbers: _findCurrentSteps(events),
      invalidCount: invalidCount,
    );
  }

  /// Every exercise by id, including deleted ones.
  final Map<String, Exercise> exercises;

  /// Every progression by id, including deleted ones.
  final Map<String, Progression> progressions;

  /// Every set, including deleted ones, in the order they were logged.
  final List<ExerciseSet> sets;

  /// How many things were skipped because their data was not valid.
  final int invalidCount;

  /// The step number last saved for each progression, by progression
  /// id. Use [currentStepNumber], which also handles missing values.
  final Map<String, int> savedStepNumbers;

  /// The progressions that are not deleted, oldest first.
  List<Progression> get activeProgressions => progressions.values
      .where((progression) => !progression.isDeleted)
      .toList();

  /// The exercises that are not deleted and not part of any progression.
  List<Exercise> get standaloneExercises {
    final inProgressions = {
      for (final progression in activeProgressions)
        for (final step in progression.steps) step.exerciseId,
    };
    return exercises.values
        .where(
          (exercise) =>
              !exercise.isDeleted && !inProgressions.contains(exercise.id),
        )
        .toList();
  }

  /// The step the user is on in [progression], counting from 1.
  ///
  /// It is 1 until a `progression_step_set` event says otherwise, and is
  /// kept within the progression's steps (it may have lost steps since).
  int currentStepNumber(Progression progression) {
    final stepNumber = savedStepNumbers[progression.id] ?? 1;
    return stepNumber.clamp(1, progression.steps.length);
  }

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

  /// The sets of [progression], grouped by day, newest day first.
  List<DaySets> progressionDays(Progression progression) {
    return _groupByDay(
      sets.where(
        (set) => set.progressionId == progression.id && !set.isDeleted,
      ),
    );
  }

  /// The sets of [exerciseId], grouped by day, newest day first.
  List<DaySets> exerciseDays(String exerciseId) {
    return _groupByDay(
      sets.where((set) => set.exerciseId == exerciseId && !set.isDeleted),
    );
  }

  /// The level reached in [progression] on each day with sets, oldest
  /// first. See [progressionLevel].
  ///
  /// If several steps were done on one day (for example after moving
  /// up), the highest level counts. Sets without a step or target (for
  /// example from other tools) are skipped.
  List<DayValue> levelHistory(Progression progression) {
    final points = <DayValue>[];
    for (final day in progressionDays(progression).reversed) {
      final valuesByStep = <int, List<int>>{};
      final targetByStep = <int, int>{};
      for (final set in day.sets) {
        final stepNumber = set.stepNumber;
        final target = set.targetPerSet;
        if (stepNumber == null || target == null) {
          continue;
        }
        valuesByStep.putIfAbsent(stepNumber, () => []).add(set.value);
        targetByStep[stepNumber] = target;
      }
      if (valuesByStep.isEmpty) {
        continue;
      }
      var bestLevel = 0.0;
      for (final stepNumber in valuesByStep.keys) {
        final progress = stepProgress(
          valuesByStep[stepNumber]!,
          targetSets: progression.stepAt(stepNumber).targetSets,
          targetPerSet: targetByStep[stepNumber]!,
        );
        bestLevel = max(bestLevel, progressionLevel(stepNumber, progress));
      }
      points.add(DayValue(day.date, bestLevel));
    }
    return points;
  }

  /// The total reps or seconds of [exerciseId] on each day, oldest
  /// first.
  List<DayValue> dailyTotals(String exerciseId) {
    return [
      for (final day in exerciseDays(exerciseId).reversed)
        DayValue(
          day.date,
          day.sets.fold(0.0, (total, set) => total + set.value),
        ),
    ];
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

/// Finds each progression's current step from `progression_step_set`
/// events. Later events win.
Map<String, int> _findCurrentSteps(List<Event> events) {
  final currentSteps = <String, int>{};
  for (final event in events) {
    if (event.module != exerciseModuleName ||
        event.type != 'progression_step_set') {
      continue;
    }
    final progressionId = event.data['progression_id'];
    final stepNumber = event.data['step_number'];
    if (progressionId is String && stepNumber is int && stepNumber >= 1) {
      currentSteps[progressionId] = stepNumber;
    }
  }
  return currentSteps;
}

/// Groups [sets] by day, newest day first; within a day, in the order
/// they were logged.
List<DaySets> _groupByDay(Iterable<ExerciseSet> sets) {
  final setsByDate = <String, List<ExerciseSet>>{};
  for (final set in sets) {
    setsByDate.putIfAbsent(set.date, () => []).add(set);
  }
  final dates = setsByDate.keys.toList()
    ..sort((first, second) => second.compareTo(first));
  return [for (final date in dates) DaySets(date, setsByDate[date]!)];
}
