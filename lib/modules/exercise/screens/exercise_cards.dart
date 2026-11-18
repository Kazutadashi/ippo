// SPDX-License-Identifier: GPL-3.0-or-later

/// The cards on the exercise screen: one per progression, and one per
/// exercise outside any progression.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../exercise.dart';
import '../exercise_set.dart';
import '../progress.dart';
import '../progression.dart';

/// A progression's card: the current step, the day's sets, progress
/// towards the target, and a button to move up when it is reached.
class ProgressionCard extends StatelessWidget {
  /// Creates the card.
  const ProgressionCard({
    super.key,
    required this.progression,
    required this.stepNumber,
    required this.exercise,
    required this.daySets,
    required this.onLogSet,
    required this.onEditSet,
    required this.onMoveToStep,
    required this.onEdit,
    required this.onHistory,
  });

  /// The progression shown.
  final Progression progression;

  /// The current step, counting from 1.
  final int stepNumber;

  /// The exercise of the current step, or null if it is missing.
  final Exercise? exercise;

  /// The sets of the current step's exercise on the day shown.
  final List<ExerciseSet> daySets;

  /// Called to log a new set.
  final VoidCallback onLogSet;

  /// Called to change or delete a set.
  final ValueChanged<ExerciseSet> onEditSet;

  /// Called with a step number to move to.
  final ValueChanged<int> onMoveToStep;

  /// Called to edit the progression.
  final VoidCallback onEdit;

  /// Called to show the progression's history.
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final step = progression.stepAt(stepNumber);
    final values = [for (final set in daySets) set.value];
    final progress = stepProgress(
      values,
      targetSets: step.targetSets,
      targetPerSet: step.targetPerSet,
    );
    final isLastStep = stepNumber == progression.steps.length;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(progression.name, style: textTheme.titleMedium),
                ),
                _StepMenu(
                  progression: progression,
                  stepNumber: stepNumber,
                  onMoveToStep: onMoveToStep,
                  onEdit: onEdit,
                ),
              ],
            ),
            Text(
              'Step $stepNumber of ${progression.steps.length}: '
              '${exercise?.name ?? '(missing exercise)'}',
            ),
            Text('Target ${step.describeTarget()}', style: textTheme.bodySmall),
            const SizedBox(height: 8),
            _SetChips(sets: daySets, onEditSet: onEditSet),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            if (progress >= 1 && !isLastStep)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.tonalIcon(
                  onPressed: () => onMoveToStep(stepNumber + 1),
                  icon: const Icon(Icons.trending_up),
                  label: Text(
                    'Target reached: move up to step ${stepNumber + 1}',
                  ),
                ),
              ),
            if (progress >= 1 && isLastStep)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Final step mastered.'),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: exercise == null ? null : onLogSet,
                  icon: const Icon(Icons.add),
                  label: const Text('Log set'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onHistory, child: const Text('History')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A card for an exercise outside any progression.
class ExerciseCard extends StatelessWidget {
  /// Creates the card.
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.daySets,
    required this.onLogSet,
    required this.onEditSet,
    required this.onEdit,
    required this.onHistory,
  });

  /// The exercise shown.
  final Exercise exercise;

  /// Its sets on the day shown.
  final List<ExerciseSet> daySets;

  /// Called to log a new set.
  final VoidCallback onLogSet;

  /// Called to change or delete a set.
  final ValueChanged<ExerciseSet> onEditSet;

  /// Called to edit the exercise.
  final VoidCallback onEdit;

  /// Called to show the exercise's history.
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit exercise',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              ],
            ),
            _SetChips(sets: daySets, onEditSet: onEditSet),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onLogSet,
                  icon: const Icon(Icons.add),
                  label: const Text('Log set'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onHistory, child: const Text('History')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The day's sets as small buttons; tapping one opens it for editing.
class _SetChips extends StatelessWidget {
  const _SetChips({required this.sets, required this.onEditSet});

  final List<ExerciseSet> sets;
  final ValueChanged<ExerciseSet> onEditSet;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) {
      return const Text('No sets on this day yet.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final set in sets)
          ActionChip(
            label: Text(
              set.weightKg == null
                  ? '${set.value}'
                  : '${set.value} +${formatAmount(set.weightKg!)} kg',
            ),
            onPressed: () => onEditSet(set),
          ),
      ],
    );
  }
}

/// The ⋮ menu of a progression card: edit, or jump to any step.
class _StepMenu extends StatelessWidget {
  const _StepMenu({
    required this.progression,
    required this.stepNumber,
    required this.onMoveToStep,
    required this.onEdit,
  });

  final Progression progression;
  final int stepNumber;
  final ValueChanged<int> onMoveToStep;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      // 0 means "edit"; other values are step numbers to move to.
      onSelected: (choice) => choice == 0 ? onEdit() : onMoveToStep(choice),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('Edit progression')),
        for (var number = 1; number <= progression.steps.length; number++)
          if (number != stepNumber)
            PopupMenuItem(value: number, child: Text('Go to step $number')),
      ],
    );
  }
}
