// SPDX-License-Identifier: GPL-3.0-or-later

/// Showing nutrients as information: energy, then protein,
/// carbohydrates and fat.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/value_text.dart';
import '../nutrients.dart';

/// Shows energy on a line of its own, large, as the number that matters
/// most; then protein, carbohydrates and fat in three equal columns
/// under it, every one aligned left. A nutrient that is not known shows
/// as "–".
class NutrientInfoRow extends StatelessWidget {
  /// Creates the summary for [nutrients].
  const NutrientInfoRow({super.key, required this.nutrients});

  /// The nutrients to show.
  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Digits large and the unit small, as on Home.
        Semantics(
          label: 'Energy',
          child: ValueText(
            formatEnergy(nutrients.energyKcal),
            style: textTheme.headlineSmall,
            unitStyle: textTheme.titleSmall?.copyWith(color: muted),
          ),
        ),
        const SizedBox(height: Spacing.small),
        InfoRow(
          values: [
            InfoValue(label: 'Protein', value: _grams('proteins_g')),
            InfoValue(label: 'Carbs', value: _grams('carbohydrates_g')),
            InfoValue(label: 'Fat', value: _grams('fat_g')),
          ],
        ),
      ],
    );
  }

  /// The grams of the nutrient [key], or "–" if not known.
  String _grams(String key) {
    final value = nutrients.values[key];
    return value == null ? '–' : '${formatAmount(value)} g';
  }
}
