// SPDX-License-Identifier: GPL-3.0-or-later

/// Nutrient values, such as energy and protein.
///
/// The field names follow `docs/data-format.md`, section "Nutrients",
/// which follows Open Food Facts.
library;

import '../../core/number_input.dart';

/// One kind of nutrient: its name in the data, on screen, and its unit.
class NutrientKind {
  /// Creates a nutrient kind, which is [partOf] another, if given.
  const NutrientKind(this.key, this.label, this.unit, {this.partOf});

  /// The field name in the data, for example `proteins_g`.
  final String key;

  /// The name on screen, for example `Protein`.
  final String label;

  /// The unit on screen, for example `g`.
  final String unit;

  /// The field name of the nutrient this one is part of, or null: sugars
  /// are part of carbohydrates, saturated fat part of fat. Screens list
  /// it just under that one, a little indented. In the data it is a
  /// nutrient of its own, with its own column over time.
  final String? partOf;
}

/// Energy for people, in whole kilocalories with a thousands separator,
/// as for steps: `1,267 kcal`. A tenth of a kilocalorie means nothing to
/// anyone, so the screen leaves it out; the data keeps it.
String formatEnergy(double kcal) => '${formatThousands(kcal.round())} kcal';

/// The field name for energy, the one nutrient that is always required.
const String energyKey = 'energy_kcal';

/// The field name of salt, in grams.
const String saltKey = 'salt_g';

/// The field name of sodium, in milligrams.
const String sodiumKey = 'sodium_mg';

/// How much salt (sodium chloride) holds a unit of sodium: salt is 2.5
/// times the sodium, as EU labeling law counts it (Regulation (EU)
/// No 1169/2011, Annex I, point 11).
const double saltPerSodium = 2.5;

/// Every nutrient Ippo knows, in the order they are shown, as on a
/// label: energy and the macronutrients first, then fats, minerals and
/// vitamins. Each field name ends in its unit (`_g`, `_mg`, `_ug` for
/// micrograms).
const List<NutrientKind> allNutrientKinds = [
  NutrientKind(energyKey, 'Energy', 'kcal'),
  NutrientKind('proteins_g', 'Protein', 'g'),
  NutrientKind('carbohydrates_g', 'Carbohydrates', 'g'),
  NutrientKind('sugars_g', 'Sugars', 'g', partOf: 'carbohydrates_g'),
  NutrientKind(
    'added_sugars_g',
    'Added sugars',
    'g',
    partOf: 'carbohydrates_g',
  ),
  NutrientKind('fiber_g', 'Fiber', 'g'),
  NutrientKind('fat_g', 'Fat', 'g'),
  NutrientKind('saturated_fat_g', 'Saturated fat', 'g', partOf: 'fat_g'),
  NutrientKind(
    'monounsaturated_fat_g',
    'Monounsaturated fat',
    'g',
    partOf: 'fat_g',
  ),
  NutrientKind(
    'polyunsaturated_fat_g',
    'Polyunsaturated fat',
    'g',
    partOf: 'fat_g',
  ),
  NutrientKind('trans_fat_g', 'Trans fat', 'g', partOf: 'fat_g'),
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

/// Matches a nutrient field name: words joined by `_`, ending in a unit
/// (`_g`, `_mg`, `_ug` or `_kcal`), such as `vitamin_b5_mg`.
final RegExp _nutrientKeyPattern = RegExp(r'^[a-z][a-z0-9_]*_(g|mg|ug|kcal)$');

/// Whether [key] looks like a nutrient field name, known or not.
bool isNutrientKey(String key) => _nutrientKeyPattern.hasMatch(key);

/// The kind of nutrient with field name [key], or null if [key] is not a
/// nutrient field name.
///
/// A nutrient Ippo does not list yet (from a newer version, or another
/// tool) still gets a kind, named from its field: `vitamin_b5_mg` is
/// "Vitamin b5" in mg. So such data is kept, shown and added up, and an
/// analysis over time simply sees it start on the day it first appears.
NutrientKind? nutrientKindOf(String key) {
  for (final kind in allNutrientKinds) {
    if (kind.key == key) {
      return kind;
    }
  }
  final match = _nutrientKeyPattern.firstMatch(key);
  if (match == null) {
    return null;
  }
  final unit = match.group(1)!;
  final words = key.substring(0, key.length - unit.length - 1).split('_');
  final name = words.join(' ');
  return NutrientKind(
    key,
    name[0].toUpperCase() + name.substring(1),
    unit == 'ug' ? 'µg' : unit,
  );
}

/// The nutrient field names in [keys], in the order to show them: those
/// Ippo lists in label order, then any others alphabetically.
List<String> orderedNutrientKeys(Iterable<String> keys) {
  final present = keys.toSet();
  return [
    for (final kind in allNutrientKinds)
      if (present.contains(kind.key)) kind.key,
    ...(present
        .where((key) => !allNutrientKinds.any((kind) => kind.key == key))
        .toList()
      ..sort()),
  ];
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
  /// known nutrient that is not a non-negative number. Fields that are
  /// not nutrient names are ignored; nutrients Ippo does not list yet are
  /// kept (see [nutrientKindOf]).
  static Nutrients? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final values = <String, double>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value == null || !isNutrientKey(entry.key)) {
        continue;
      }
      final isKnown = allNutrientKinds.any((kind) => kind.key == entry.key);
      if (value is! num || value < 0) {
        // A known nutrient must be valid; an unknown one is skipped.
        if (isKnown) {
          return null;
        }
        continue;
      }
      values[entry.key] = value.toDouble();
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
      for (final key in orderedNutrientKeys(values.keys))
        key: jsonNumber(values[key]!),
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

  /// These nutrients with salt and sodium both known when either is.
  ///
  /// Salt and sodium are one measurement in two forms: salt (sodium
  /// chloride) is 2.5 times the sodium. Labels in the EU give salt, in
  /// the US sodium, so a food has one or the other. Filling in the
  /// missing one before adding up a day keeps the day's salt and sodium
  /// in step; otherwise each would count only the foods that named it.
  /// The data keeps what was entered; this is only worked out to show.
  Nutrients withSaltAndSodium() {
    final salt = values[saltKey];
    final sodium = values[sodiumKey];
    if ((salt == null) == (sodium == null)) {
      return this;
    }
    return Nutrients({
      ...values,
      saltKey: salt ?? roundToTenth(sodium! * saltPerSodium / 1000),
      sodiumKey: sodium ?? (salt! * 1000 / saltPerSodium).roundToDouble(),
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
