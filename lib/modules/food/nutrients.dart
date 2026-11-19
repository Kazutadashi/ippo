// SPDX-License-Identifier: GPL-3.0-or-later

/// Nutrient values, such as energy and protein.
///
/// The field names follow `docs/data-format.md`, section "Nutrients",
/// which follows Open Food Facts.
library;

import '../../core/number_input.dart';

/// One kind of nutrient: its name in the data, on screen, and its unit.
class NutrientKind {
  /// Creates a nutrient kind.
  const NutrientKind(this.key, this.label, this.unit);

  /// The field name in the data, for example `proteins_g`.
  final String key;

  /// The name on screen, for example `Protein`.
  final String label;

  /// The unit on screen, for example `g`.
  final String unit;
}

/// Energy for people, in whole kilocalories: `1267 kcal`. A tenth of a
/// kilocalorie means nothing to anyone, so the screen leaves it out;
/// the data keeps it.
String formatEnergy(double kcal) => '${kcal.round()} kcal';

/// Grams for people: whole grams from 10 g on (`168 g`), and a tenth
/// below that, where it still matters (`2.5 g`). The data keeps every
/// decimal.
String formatGrams(double grams) =>
    grams >= 10 ? '${grams.round()} g' : '${formatAmount(grams)} g';

/// The field name for energy, the one nutrient that is always required.
const String energyKey = 'energy_kcal';

/// Every nutrient Ippo knows, in the order they are shown, as on a
/// label: energy and the macronutrients first, then fats, minerals and
/// vitamins. Each field name ends in its unit (`_g`, `_mg`, `_ug` for
/// micrograms).
const List<NutrientKind> allNutrientKinds = [
  NutrientKind(energyKey, 'Energy', 'kcal'),
  NutrientKind('proteins_g', 'Protein', 'g'),
  NutrientKind('carbohydrates_g', 'Carbohydrates', 'g'),
  NutrientKind('sugars_g', '  of which sugars', 'g'),
  NutrientKind('added_sugars_g', '  of which added sugars', 'g'),
  NutrientKind('fiber_g', 'Fiber', 'g'),
  NutrientKind('fat_g', 'Fat', 'g'),
  NutrientKind('saturated_fat_g', '  of which saturated', 'g'),
  NutrientKind('monounsaturated_fat_g', '  of which monounsaturated', 'g'),
  NutrientKind('polyunsaturated_fat_g', '  of which polyunsaturated', 'g'),
  NutrientKind('trans_fat_g', '  of which trans', 'g'),
  NutrientKind('cholesterol_mg', 'Cholesterol', 'mg'),
  NutrientKind('salt_g', 'Salt', 'g'),
  NutrientKind('sodium_mg', 'Sodium', 'mg'),
  NutrientKind('potassium_mg', 'Potassium', 'mg'),
  NutrientKind('calcium_mg', 'Calcium', 'mg'),
  NutrientKind('iron_mg', 'Iron', 'mg'),
  NutrientKind('magnesium_mg', 'Magnesium', 'mg'),
  NutrientKind('zinc_mg', 'Zinc', 'mg'),
  NutrientKind('phosphorus_mg', 'Phosphorus', 'mg'),
  NutrientKind('vitamin_a_ug', 'Vitamin A', 'µg'),
  NutrientKind('vitamin_c_mg', 'Vitamin C', 'mg'),
  NutrientKind('vitamin_d_ug', 'Vitamin D', 'µg'),
  NutrientKind('vitamin_e_mg', 'Vitamin E', 'mg'),
  NutrientKind('vitamin_k_ug', 'Vitamin K', 'µg'),
  NutrientKind('thiamin_mg', 'Thiamin (B1)', 'mg'),
  NutrientKind('riboflavin_mg', 'Riboflavin (B2)', 'mg'),
  NutrientKind('niacin_mg', 'Niacin (B3)', 'mg'),
  NutrientKind('vitamin_b6_mg', 'Vitamin B6', 'mg'),
  NutrientKind('folate_ug', 'Folate', 'µg'),
  NutrientKind('vitamin_b12_ug', 'Vitamin B12', 'µg'),
];

/// The kind of nutrient with field name [key], or null if unknown.
NutrientKind? nutrientKindOf(String key) {
  for (final kind in allNutrientKinds) {
    if (kind.key == key) {
      return kind;
    }
  }
  return null;
}

/// A set of nutrient values. Nutrients that are not known are missing,
/// which is different from zero.
class Nutrients {
  /// Creates nutrients from values by field name, for example
  /// `{'energy_kcal': 389, 'proteins_g': 13.2}`.
  const Nutrients(this.values);

  /// No nutrients at all: the start for adding up a day.
  static const Nutrients none = Nutrients({});

  /// The values by field name. Only known nutrients are present.
  final Map<String, double> values;

  /// The energy in kilocalories, or 0 if unknown.
  double get energyKcal => values[energyKey] ?? 0;

  /// Reads nutrients from event data.
  ///
  /// Returns null if [json] is not an object, has no energy, or has a
  /// known nutrient that is not a non-negative number. Unknown fields are
  /// ignored, so data from newer app versions still loads.
  static Nutrients? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final values = <String, double>{};
    for (final kind in allNutrientKinds) {
      final value = json[kind.key];
      if (value == null) {
        continue;
      }
      if (value is! num || value < 0) {
        return null;
      }
      values[kind.key] = value.toDouble();
    }
    if (!values.containsKey(energyKey)) {
      return null;
    }
    return Nutrients(values);
  }

  /// Turns the nutrients into event data. Whole numbers are written
  /// without `.0`, so files stay easy to read.
  Map<String, Object?> toJson() {
    return {
      for (final kind in allNutrientKinds)
        if (values.containsKey(kind.key))
          kind.key: jsonNumber(values[kind.key]!),
    };
  }

  /// Returns these nutrients multiplied by [factor], rounded to one
  /// decimal place. For example, nutrients per 100 g scaled by 1.5 give
  /// the nutrients in 150 g.
  Nutrients scaledBy(double factor) {
    return Nutrients({
      for (final entry in values.entries)
        entry.key: roundToTenth(entry.value * factor),
    });
  }

  /// Returns the sum of these nutrients and [other].
  ///
  /// A nutrient known in only one of them is still added, so a day's
  /// total counts every value that was recorded.
  Nutrients plus(Nutrients other) {
    final sums = Map<String, double>.of(values);
    for (final entry in other.values.entries) {
      sums[entry.key] = roundToTenth((sums[entry.key] ?? 0) + entry.value);
    }
    return Nutrients(sums);
  }
}
