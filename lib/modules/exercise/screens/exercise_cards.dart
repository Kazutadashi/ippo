// SPDX-License-Identifier: GPL-3.0-or-later

/// The card shown for each exercise: the day's sets beside the last
/// session's, and a row to add the next set.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_set.dart';
import 'add_set_row.dart';

/// An exercise's card: the standard header (name and Edit), a small
/// table of sets, and the row to add one.
///
/// The table says what every number is: a column per set ("Set 1",
/// "Set 2"), a row for the day shown, and under it, in grey, the last
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
          icon: Icons.fitness_center,
          title: exercise.name,
          action: HeaderEditButton(onPressed: onEdit),
        ),
        if (hasTable) ...[
          _SetTable(
            unit: exercise.measuredIn == MeasuredIn.reps ? 'reps' : 'seconds',
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

/// The width of the column of row names ("Today", "Mon 16 Nov").
const double _rowNameWidth = 80;

/// The width of one set's column: five sets fit beside the row names
/// on a phone; more scroll sideways.
const double _setWidth = 50;

/// A small table of sets: a column per set, a row for the day shown and
/// a grey row for the last session. Tap a number of the day shown to
/// change or delete that set.
class _SetTable extends StatelessWidget {
  const _SetTable({
    required this.unit,
    required this.dayLabel,
    required this.daySets,
    required this.previousLabel,
    required this.previousSets,
    required this.onEditSet,
  });

  /// `reps` or `seconds`, in the corner: what every number counts.
  final String unit;
  final String dayLabel;
  final List<ExerciseSet> daySets;

  /// The last session's day, or null for no grey row.
  final String? previousLabel;
  final List<ExerciseSet> previousSets;
  final ValueChanged<ExerciseSet> onEditSet;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final previousLabel = this.previousLabel;
    final columns = daySets.length > previousSets.length
        ? daySets.length
        : previousSets.length;
    final small = textTheme.labelMedium?.copyWith(color: muted);
    // Many sets scroll sideways rather than squeeze.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            name: Text(unit, style: small),
            cells: [
              for (var index = 0; index < columns; index++)
                Text('Set ${index + 1}', style: small),
            ],
          ),
          const SizedBox(height: Spacing.tight),
          _row(
            name: Text(dayLabel, style: textTheme.labelLarge),
            cells: [
              for (var index = 0; index < columns; index++)
                index < daySets.length
                    ? _DayValue(
                        set: daySets[index],
                        number: index + 1,
                        unit: unit,
                        onTap: () => onEditSet(daySets[index]),
                      )
                    // Not done yet: a quiet dash where the set would go.
                    : Text(
                        '–',
                        style: textTheme.titleMedium?.copyWith(color: muted),
                      ),
            ],
          ),
          if (previousLabel != null) ...[
            const SizedBox(height: Spacing.tight),
            _row(
              name: Text(previousLabel, style: small),
              cells: [
                for (var index = 0; index < columns; index++)
                  Text(
                    index < previousSets.length
                        ? _describe(previousSets[index])
                        : '',
                    style: textTheme.bodyMedium?.copyWith(color: muted),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// One row: its name in the first column, then a cell per set.
  Widget _row({required Widget name, required List<Widget> cells}) {
    return Row(
      children: [
        SizedBox(width: _rowNameWidth, child: name),
        for (final cell in cells)
          SizedBox(
            width: _setWidth,
            child: Center(child: cell),
          ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
