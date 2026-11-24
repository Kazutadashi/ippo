// SPDX-License-Identifier: GPL-3.0-or-later

/// Showing nutrients as information: energy, then protein,
/// carbohydrates and fat.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/value_text.dart';
import '../daily_references.dart';
import '../nutrients.dart';
import 'nutrient_bars.dart';

/// Shows energy at the left, large, as the number that matters most,
/// and protein, carbohydrates and fat at the right in three equal
/// columns, each with a thin bar of how much of its daily amount it is.
/// One row, so the card uses its whole width. With an [energyTarget],
/// the energy says "of 2000 kcal" under it. A nutrient that is not known
/// shows as "–".
class NutrientInfoRow extends StatelessWidget {
  /// Creates the summary for [nutrients], against [references] (the
  /// daily amounts by field name; see `daily_references.dart`).
  const NutrientInfoRow({
    super.key,
    required this.nutrients,
    required this.references,
    this.energyTarget,
  });

  /// The nutrients to show.
  final Nutrients nutrients;

  /// The normal amount a day of each nutrient.
  final Map<String, double> references;

  /// The daily energy limit, if one is set.
  final double? energyTarget;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final energyTarget = this.energyTarget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Digits large and the unit small, as on Home; a long value
        // shrinks rather than wrapping.
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: 'Energy',
                  child: ValueText(
                    formatEnergy(nutrients.energyKcal),
                    style: textTheme.headlineSmall,
                    unitStyle: textTheme.titleSmall?.copyWith(color: muted),
                  ),
                ),
              ),
              if (energyTarget != null)
                Text(
                  'of ${formatEnergy(energyTarget)}',
                  style: textTheme.bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          flex: 6,
          child: NutrientBars(
            showsReference: true,
            amounts: [
              for (final (key, label) in const [
                ('proteins_g', 'Protein'),
                ('carbohydrates_g', 'Carbs'),
                ('fat_g', 'Fat'),
              ])
                NutrientAmount(
                  key,
                  label,
                  nutrients.values[key],
                  references[key],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Every nutrient known for the day besides energy, protein, carbs and
/// fat, one per line: its name, how much, and of how much a day, with a
/// thin bar. Nutrients that no food gave are left out.
class AllNutrientsList extends StatelessWidget {
  /// Creates the list.
  const AllNutrientsList({
    super.key,
    required this.nutrients,
    required this.references,
  });

  /// The day's nutrients.
  final Nutrients nutrients;

  /// The normal amount a day of each nutrient.
  final Map<String, double> references;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    const shownAbove = {energyKey, 'proteins_g', 'carbohydrates_g', 'fat_g'};
    // Every nutrient any food gave, including ones Ippo does not list
    // yet, so a new nutrient shows up the day it is first logged.
    // Salt and sodium are the same thing in two units: show both,
    // always in step.
    final nutrients = this.nutrients.withSaltAndSodium();
    final kinds = [
      for (final key in orderedNutrientKeys(nutrients.values.keys))
        // Salt and sodium are one measurement: one row, for salt, with
        // the sodium written under it.
        if (!shownAbove.contains(key) && key != sodiumKey) nutrientKindOf(key)!,
    ];
    if (kinds.isEmpty) {
      return const NoteText('No other nutrients are known for this day.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in kinds) _line(kind, nutrients, textTheme, muted),
      ],
    );
  }

  /// One nutrient: its name, the amount, and "of … a day" with a bar
  /// when it has a daily reference amount.
  Widget _line(
    NutrientKind kind,
    Nutrients nutrients,
    TextTheme textTheme,
    Color muted,
  ) {
    final amount = nutrients.values[kind.key]!;
    final reference = references[kind.key];
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // A part of the nutrient above (sugars of carbohydrates) is
              // indented a little under it.
              if (kind.partOf != null) const SizedBox(width: Spacing.medium),
              Expanded(child: Text(kind.label, style: textTheme.bodyMedium)),
              Text(
                formatNutrientAmount(amount, kind.unit),
                style: textTheme.titleSmall,
              ),
              if (reference != null) ...[
                const SizedBox(width: Spacing.tight),
                // Against the daily reference amount.
                Text(
                  'of ${formatNutrientAmount(reference, kind.unit)} a day',
                  style: textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
          // The same amount as sodium, for labels and advice that use it.
          if (kind.key == saltKey && nutrients.values[sodiumKey] != null)
            Text(
              'Sodium ${formatNutrientAmount(nutrients.values[sodiumKey]!, 'mg')}',
              style: textTheme.bodySmall?.copyWith(color: muted),
            ),
          if (reference != null) ...[
            const SizedBox(height: 3),
            ShareBar(
              share: amount / reference,
              isLimit: isLimitNutrient(kind.key),
            ),
          ],
        ],
      ),
    );
  }
}
