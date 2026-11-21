// SPDX-License-Identifier: GPL-3.0-or-later

/// The Exercise tab's charts: steps, and the best set of each exercise.
library;

import 'dart:math' as math;

import '../../core/app_state.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import 'exercise_log.dart';

/// Steps each day, then one chart per exercise done on at least two
/// days: the most reps (or seconds) in one set each day, which is how
/// strength shows in bodyweight training.
List<ChartSpec> exerciseCharts(AppState appState) {
  final log = ExerciseLog.of(appState);
  final stepDates = {
    for (final count in log.steps)
      if (!count.isDeleted) count.date,
  };
  return [
    if (stepDates.isNotEmpty)
      ChartSpec(
        title: 'Steps',
        values: dailyValues(
          stepDates,
          (date) => log.stepsOn(date)?.steps.toDouble(),
        ),
        format: (steps) => formatThousands(steps.round()),
        mark: ChartMark.bars,
        startsAtZero: true,
        isWholeNumber: true,
        isRunningTotal: true,
      ),
    ..._bestSetCharts(log),
  ];
}

/// One chart per exercise with sets on two days or more, in the order
/// the exercises were created.
List<ChartSpec> _bestSetCharts(ExerciseLog log) {
  // The best set of each exercise on each day: exercise id, then date.
  final bestSets = <String, Map<String, double>>{};
  for (final set in log.sets) {
    if (set.isDeleted) {
      continue;
    }
    final byDate = bestSets.putIfAbsent(set.exerciseId, () => {});
    byDate[set.date] = math.max(byDate[set.date] ?? 0, set.value.toDouble());
  }
  return [
    for (final exercise in log.activeExercises)
      if ((bestSets[exercise.id]?.length ?? 0) >= 2)
        ChartSpec(
          title: exercise.name,
          unit: exercise.measuredIn.unit,
          values: dailyValues(
            bestSets[exercise.id]!.keys,
            (date) => bestSets[exercise.id]![date],
          ),
          format: (value) =>
              '${formatAmount(value)} ${exercise.measuredIn.unit}',
          valueLabel: 'Best set each day',
          countLabel: 'Sessions',
          isWholeNumber: true,
        ),
  ];
}
