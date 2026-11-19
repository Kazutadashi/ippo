// SPDX-License-Identifier: GPL-3.0-or-later

/// Showing nutrients as information: energy, then protein,
/// carbohydrates and fat.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/info_tile.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/value_text.dart';
import '../nutrients.dart';

/// Shows energy at the left, large, as the number that matters most,
/// and protein, carbohydrates and fat at the right in three equal
/// columns, each a small grey label above its value, as on Home. One
/// row, so the card uses its whole width. A nutrient that is not known
/// shows as "–".
class NutrientInfoRow extends StatelessWidget {
  /// Creates the summary for [nutrients].
  const NutrientInfoRow({super.key, required this.nutrients});

  /// The nutrients to show.
  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        // Digits large and the unit small, as on Home; a long value
        // shrinks rather than wrapping.
        Expanded(
          flex: 4,
          child: FittedBox(
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
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          flex: 6,
          child: LabelledValues(
            details: [
              TileDetail(_grams('proteins_g'), label: 'Protein'),
              TileDetail(_grams('carbohydrates_g'), label: 'Carbs'),
              TileDetail(_grams('fat_g'), label: 'Fat'),
            ],
          ),
        ),
      ],
    );
  }

  /// The grams of the nutrient [key], or "–" if not known.
  String _grams(String key) {
    final value = nutrients.values[key];
    return value == null ? '–' : formatGrams(value);
  }
}
