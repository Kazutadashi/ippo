// SPDX-License-Identifier: GPL-3.0-or-later

/// A short summary of nutrients: energy, then the main macronutrients.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../nutrients.dart';

/// Shows energy large, and protein, carbohydrates and fat below it.
/// Nutrients that are not known are left out.
class NutrientSummary extends StatelessWidget {
  /// Creates a summary of [nutrients].
  const NutrientSummary({super.key, required this.nutrients});

  /// The nutrients to show.
  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatAmount(nutrients.energyKcal)} kcal',
          style: textTheme.headlineSmall,
        ),
        Text(describeMacronutrients(nutrients), style: textTheme.bodyMedium),
      ],
    );
  }
}

/// Writes protein, carbohydrates and fat in one line, for example
/// `Protein 12 g · Carbs 50 g · Fat 6.5 g`. Unknown ones are left out.
String describeMacronutrients(Nutrients nutrients) {
  const shown = {
    'proteins_g': 'Protein',
    'carbohydrates_g': 'Carbs',
    'fat_g': 'Fat',
  };
  final parts = [
    for (final entry in shown.entries)
      if (nutrients.values.containsKey(entry.key))
        '${entry.value} ${formatAmount(nutrients.values[entry.key]!)} g',
  ];
  return parts.join(' · ');
}
