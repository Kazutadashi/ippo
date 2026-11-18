// SPDX-License-Identifier: GPL-3.0-or-later

/// The card shown for each exercise: the day's sets and fields to add
/// more.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_set.dart';
import 'quick_set_row.dart';

/// An exercise's card: the standard header (name and Edit), the day's
/// sets, and the quick-add fields.
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

  /// The value to start the quick-add fields with, usually the last
  /// set's.
  final int? startValue;

  /// Called with reps (or seconds) and a number of sets to add.
  final Future<void> Function(int value, int setCount) onAddSets;

  /// Called to change or delete a set.
  final ValueChanged<ExerciseSet> onEditSet;

  /// Called to rename or delete the exercise.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        CardHeader(
          icon: Icons.fitness_center,
          title: exercise.name,
          action: HeaderEditButton(onPressed: onEdit),
        ),
        // The day's sets, if any, as small chips (tap one to change it).
        // With none yet, the fields below speak for themselves.
        if (daySets.isNotEmpty) ...[
          _SetChips(sets: daySets, onEditSet: onEditSet),
          const SizedBox(height: Spacing.small),
        ],
        const SizedBox(height: Spacing.tight),
        QuickSetRow(
          measuredIn: exercise.measuredIn,
          startValue: startValue,
          onAddSets: onAddSets,
        ),
      ],
    );
  }
}

/// The day's sets as small chips; tapping one opens it for changing.
class _SetChips extends StatelessWidget {
  const _SetChips({required this.sets, required this.onEditSet});

  final List<ExerciseSet> sets;
  final ValueChanged<ExerciseSet> onEditSet;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.small,
      runSpacing: Spacing.tight,
      children: [
        for (final set in sets)
          ActionChip(
            tooltip: 'Change or delete this set',
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
