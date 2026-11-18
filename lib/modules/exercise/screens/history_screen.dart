// SPDX-License-Identifier: GPL-3.0-or-later

/// Progress over time for one progression or one exercise: a chart and
/// a list of past days.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/widgets/line_chart.dart';
import '../exercise_log.dart';
import '../exercise_set.dart';

/// Shows the history of a progression (by [progressionId]) or of a
/// single exercise (by [exerciseId]). Exactly one of them is given.
class HistoryScreen extends StatelessWidget {
  /// Creates the history of a progression.
  const HistoryScreen.progression({
    super.key,
    required this.appState,
    required String this.progressionId,
  }) : exerciseId = null;

  /// Creates the history of an exercise.
  const HistoryScreen.exercise({
    super.key,
    required this.appState,
    required String this.exerciseId,
  }) : progressionId = null;

  /// The app-wide state.
  final AppState appState;

  /// The progression to show, if this is a progression's history.
  final String? progressionId;

  /// The exercise to show, if this is an exercise's history.
  final String? exerciseId;

  @override
  Widget build(BuildContext context) {
    final log = ExerciseLog.fromEvents(appState.eventLog?.events ?? []);
    final progression = log.progressions[progressionId];
    final exercise = log.exercises[exerciseId];

    final String title;
    final String chartCaption;
    final List<DayValue> chartPoints;
    final List<DaySets> days;
    if (progression != null) {
      title = progression.name;
      chartCaption =
          'Level: steps passed plus progress towards the current '
          'target. 2.6 means step 3, 60% of the way.';
      chartPoints = log.levelHistory(progression);
      days = log.progressionDays(progression);
    } else if (exercise != null) {
      title = exercise.name;
      chartCaption = 'Total ${exercise.measuredIn.name} per day.';
      chartPoints = log.dailyTotals(exercise.id);
      days = log.exerciseDays(exercise.id);
    } else {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DayLineChart(points: chartPoints),
          const SizedBox(height: 8),
          Text(chartCaption, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (days.isEmpty) const Text('No sets logged yet.'),
          for (final day in days)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(day.date),
              subtitle: Text(_describeDay(log, day.sets)),
            ),
        ],
      ),
    );
  }
}

/// Describes one day's sets, for example
/// `Box squat (step 2): 12, 10, 8 +5 kg`. Sets in a row with the same
/// exercise and step share one line.
String _describeDay(ExerciseLog log, List<ExerciseSet> sets) {
  final lines = <String>[];
  var currentLabel = '';
  var currentValues = <String>[];
  for (final set in sets) {
    final label = _labelOf(log, set);
    if (label != currentLabel && currentValues.isNotEmpty) {
      lines.add('$currentLabel: ${currentValues.join(', ')}');
      currentValues = [];
    }
    currentLabel = label;
    currentValues.add(_valueOf(set));
  }
  if (currentValues.isNotEmpty) {
    lines.add('$currentLabel: ${currentValues.join(', ')}');
  }
  return lines.join('\n');
}

/// The exercise name, with the step if the set was part of a
/// progression, for example `Box squat (step 2)`.
String _labelOf(ExerciseLog log, ExerciseSet set) {
  final name = log.exercises[set.exerciseId]?.name ?? '(unknown)';
  final stepNumber = set.stepNumber;
  return stepNumber == null ? name : '$name (step $stepNumber)';
}

/// The set's value, with any added weight, for example `8 +5 kg`.
String _valueOf(ExerciseSet set) {
  final weightKg = set.weightKg;
  return weightKg == null
      ? '${set.value}'
      : '${set.value} +${formatAmount(weightKg)} kg';
}
