// SPDX-License-Identifier: GPL-3.0-or-later

/// Showing nutrients as a row of information: energy, protein,
/// carbohydrates and fat.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../../../core/widgets/section_card.dart';
import '../nutrients.dart';

/// Shows energy, protein, carbohydrates and fat side by side. A
/// nutrient that is not known shows as "–".
class NutrientInfoRow extends StatelessWidget {
  /// Creates the row for [nutrients].
  const NutrientInfoRow({super.key, required this.nutrients});

  /// The nutrients to show.
  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    return InfoRow(
      // Energy has the longest value ("1234 kcal"), so it gets more room.
      flexes: const [3, 2, 2, 2],
      values: [
        InfoValue(
          label: 'Energy',
          value: '${formatAmount(nutrients.energyKcal)} kcal',
        ),
        InfoValue(label: 'Protein', value: _grams('proteins_g')),
        InfoValue(label: 'Carbs', value: _grams('carbohydrates_g')),
        InfoValue(label: 'Fat', value: _grams('fat_g')),
      ],
    );
  }

  /// The grams of the nutrient [key], or "–" if not known.
  String _grams(String key) {
    final value = nutrients.values[key];
    return value == null ? '–' : '${formatAmount(value)} g';
  }
}
