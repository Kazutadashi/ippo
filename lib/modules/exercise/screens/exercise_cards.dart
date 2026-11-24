// SPDX-License-Identifier: GPL-3.0-or-later

/// The card shown for each exercise: the day's sets beside the last
/// session's, and a row to add the next set.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/dumbbell_icon.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_set.dart';
import 'add_set_row.dart';

/// An exercise's card: the standard header (name and Edit), a small
/// table of sets, and the row to add one.
///
/// The table says what every number is: a column per set ("Set 1",
/// "Set 2"), a row for the day shown, and under it, in gray, the last
/// session before it, so it is plain whether the day went better.
class ExerciseCard extends StatelessWidget {
  /// Creates the card.
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.day,
    required this.daySets,
    required this.previousDate,
    required this.previousSets,
    required this.startValue,
    required this.onAddSet,
    required this.onEditSet,
    required this.onEdit,
  });

  /// The exercise shown.
  final Exercise exercise;

  /// The day shown.
  final DateTime day;

  /// Its sets on [day].
  final List<ExerciseSet> daySets;

  /// The last day before [day] with sets, or null if there is none.
  final DateTime? previousDate;

  /// The sets on [previousDate]; empty without one.
  final List<ExerciseSet> previousSets;

  /// The value to start the add row with, usually the last set's.
  final int? startValue;

  /// Called with reps (or seconds) to add one set.
  final Future<void> Function(int value) onAddSet;

  /// Called to change or delete a set.
  final ValueChanged<ExerciseSet> onEditSet;

  /// Called to rename or delete the exercise.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final previousDate = this.previousDate;
    final hasTable = daySets.isNotEmpty || previousDate != null;
    return SectionCard(
      children: [
        CardHeader(
          iconWidget: const DumbbellIcon(),
          title: exercise.name,
          action: HeaderEditButton(onPressed: onEdit),
        ),
        if (hasTable) ...[
          _SetTable(
            unit: exercise.measuredIn == MeasuredIn.reps ? 'Reps' : 'Seconds',
            dayLabel: describeDay(day),
            daySets: daySets,
            previousLabel: previousDate == null
                ? null
                : describeDay(previousDate),
            previousSets: previousSets,
            onEditSet: onEditSet,
          ),
          const SizedBox(height: Spacing.medium),
        ],
        AddSetRow(
          measuredIn: exercise.measuredIn,
          startValue: startValue,
          onAddSet: onAddSet,
        ),
      ],
    );
  }
}

/// The width of the day names on the left, so the sets line up.
const double _dayWidth = 84;

/// The sets of the day shown, then those of the last time before, as two
/// short lines:
///
/// ```
/// Today        [17] [15] [13]  reps
/// Tue 17 Nov    16 · 14 · 12
/// ```
///
/// Each of the day's sets is a small chip; tap it to change or delete it.
/// The earlier ones are quiet text, there to beat.
class _SetTable extends StatelessWidget {
  const _SetTable({
    required this.unit,
    required this.dayLabel,
    required this.daySets,
    required this.previousLabel,
    required this.previousSets,
    required this.onEditSet,
  });

  final String unit;
  final String dayLabel;
  final List<ExerciseSet> daySets;

  final String? previousLabel;
  final List<ExerciseSet> previousSets;
  final ValueChanged<ExerciseSet> onEditSet;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final previousLabel = this.previousLabel;
    final unitText = Text(
      unit.toLowerCase(),
      style: textTheme.labelMedium?.copyWith(color: muted),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(
          Text(dayLabel, style: textTheme.labelLarge),
          daySets.isEmpty
              ? Text(
                  'No sets yet',
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                )
              : Wrap(
                  spacing: Spacing.tight,
                  runSpacing: Spacing.tight,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var index = 0; index < daySets.length; index++)
                      _DayValue(
                        set: daySets[index],
                        number: index + 1,
                        unit: unit,
                        onTap: () => onEditSet(daySets[index]),
                      ),
                    unitText,
                  ],
                ),
        ),
        if (previousLabel != null && previousSets.isNotEmpty) ...[
          const SizedBox(height: Spacing.tight),
          _line(
            Text(
              previousLabel,
              style: textTheme.labelMedium?.copyWith(color: muted),
            ),
            Text(
              '${previousSets.map(_describe).join(' · ')}'
              '${daySets.isEmpty ? ' ${unit.toLowerCase()}' : ''}',
              style: textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
        ],
      ],
    );
  }

  /// A day's name on the left and its sets after it.
  Widget _line(Widget name, Widget sets) {
    return Row(
      children: [
        SizedBox(width: _dayWidth, child: name),
        Expanded(child: sets),
      ],
    );
  }
}

/// A set of the day shown: its number, large, and a weight under it if
/// there was one. Tap it to change or delete the set.
class _DayValue extends StatelessWidget {
  const _DayValue({
    required this.set,
    required this.number,
    required this.unit,
    required this.onTap,
  });

  final ExerciseSet set;
  final int number;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weight = set.weightKg;
    return Semantics(
      button: true,
      label:
          'Set $number: ${set.value} $unit'
          '${weight == null ? '' : ', plus ${formatAmount(weight)} kg'}',
      hint: 'Change or delete this set',
      excludeSemantics: true,
      // A small chip in the accent tint, like other logged things.
      child: Material(
        color: Theme.of(context).chipTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${set.value}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (weight != null)
                  Text(
                    '+${formatAmount(weight)} kg',
                    style: textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A set of the last session, in short: `20`, or `20 +5 kg`.
String _describe(ExerciseSet set) {
  final weight = set.weightKg;
  return weight == null
      ? '${set.value}'
      : '${set.value} +${formatAmount(weight)}';
}
