// SPDX-License-Identifier: GPL-3.0-or-later

/// The card shown for each exercise: today's sets and a row to add more.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../exercise.dart';
import '../exercise_set.dart';
import 'quick_set_row.dart';

/// An exercise's card: its name, the day's sets, and the quick-add row.
class ExerciseCard extends StatelessWidget {
  /// Creates the card.
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.daySets,
    required this.startValue,
    required this.onAddSets,
    required this.onEditSet,
    required this.onEdit,
  });

  /// The exercise shown.
  final Exercise exercise;

  /// Its sets on the day shown.
  final List<ExerciseSet> daySets;

  /// The value to start the quick-add row with, usually the last set's.
  final int? startValue;

  /// Called with reps (or seconds) and a number of sets to add.
  final Future<void> Function(int value, int setCount) onAddSets;

  /// Called to change or delete a set.
  final ValueChanged<ExerciseSet> onEditSet;

  /// Called to rename or delete the exercise.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  tooltip: 'Rename or delete',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              ],
            ),
            _SetChips(sets: daySets, onEditSet: onEditSet),
            const SizedBox(height: 8),
            QuickSetRow(
              measuredIn: exercise.measuredIn,
              startValue: startValue,
              onAddSets: onAddSets,
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
