// SPDX-License-Identifier: GPL-3.0-or-later

/// How much of each nutrient a day is normal, to put a day's totals in
/// context ("73 g of 50 g protein").
///
/// Sources:
///
/// - Energy, fat, saturates, carbohydrate, sugars, protein and salt: the
///   EU's reference intakes for an average adult (Regulation (EU) No
///   1169/2011, Annex XIII, part B), for 2000 kcal a day.
/// - Vitamins and minerals: the EU's nutrient reference values (the same
///   regulation, Annex XIII, part A).
/// - Fibre: the European Food Safety Authority's adequate intake for
///   adults, 25 g (the EU has no reference intake for it).
/// - Cholesterol and added sugars: the US daily values (21 CFR 101.9),
///   as the EU has none.
///
/// They are averages for adults, not targets for any one person.
library;

import '../body/body_log.dart';
import 'nutrients.dart';

/// The reference intakes for 2000 kcal a day.
const Map<String, double> _referencesFor2000Kcal = {
  energyKey: 2000,
  'fat_g': 70,
  'saturated_fat_g': 20,
  'carbohydrates_g': 260,
  'sugars_g': 90,
  'proteins_g': 50,
  'salt_g': 6,
  'fiber_g': 25,
  'sodium_mg': 2400,
  'cholesterol_mg': 300,
  'added_sugars_g': 50,
  'vitamin_a_ug': 800,
  'vitamin_d_ug': 5,
  'vitamin_e_mg': 12,
  'vitamin_k_ug': 75,
  'vitamin_c_mg': 80,
  'thiamin_mg': 1.1,
  'riboflavin_mg': 1.4,
  'niacin_mg': 16,
  'vitamin_b6_mg': 1.4,
  'folate_ug': 200,
  'vitamin_b12_ug': 2.5,
  'potassium_mg': 2000,
  'calcium_mg': 800,
  'phosphorus_mg': 700,
  'magnesium_mg': 375,
  'iron_mg': 14,
  'zinc_mg': 10,
};

/// The nutrients that come with the energy: with a lower or higher
/// energy target, their references scale with it.
const Set<String> _scalesWithEnergy = {
  'fat_g',
  'saturated_fat_g',
  'carbohydrates_g',
  'sugars_g',
  'added_sugars_g',
};

/// The grams of protein a day per kilogram of body weight: the European
/// Food Safety Authority's population reference intake for adults.
const double proteinGramsPerKg = 0.83;

/// The normal amount a day of each nutrient that has one, by field name.
///
/// With an [energyTarget], energy is that target, and fat, saturates,
/// carbohydrate and sugars scale with it. With a [weightKg], protein is
/// [proteinGramsPerKg] for each kilogram.
Map<String, double> dailyReferences({double? energyTarget, double? weightKg}) {
  final energy = energyTarget ?? 2000;
  final references = <String, double>{};
  for (final entry in _referencesFor2000Kcal.entries) {
    var amount = entry.value;
    if (entry.key == energyKey) {
      amount = energy;
    } else if (_scalesWithEnergy.contains(entry.key)) {
      amount = entry.value * energy / 2000;
    }
    references[entry.key] = amount;
  }
  if (weightKg != null) {
    references['proteins_g'] = weightKg * proteinGramsPerKg;
  }
  return references;
}

/// The amounts a day for [date] (`YYYY-MM-DD`), from the body details
/// in [body]: the energy target that applies that day, the latest
/// weight, and in place of a reference amount, any goal of the user's own
/// that applies that day (see `BodyLog.nutrientTargetOn`).
Map<String, double> dailyReferencesOn(BodyLog body, String date) {
  final references = dailyReferences(
    energyTarget: body.energyTargetOn(date),
    weightKg: body.weightAsOf(date),
  );
  for (final nutrient in goalNutrients) {
    final own = body.nutrientTargetOn(nutrient, date)?.amount;
    if (own != null) {
      references[nutrient] = own;
    }
  }
  return references;
}

/// The nutrients whose daily amount the user can set as a goal of their
/// own, in the order shown (energy has its own limit).
const List<String> goalNutrients = [
  'proteins_g',
  'carbohydrates_g',
  'sugars_g',
  'added_sugars_g',
  'fiber_g',
  'fat_g',
  'saturated_fat_g',
  'salt_g',
];

/// The nutrients whose daily amount is a most: eating more than it is
/// going over, shown in red. For the others (protein, fibre, vitamins and
/// minerals) the amount is a least, and more is fine.
const Set<String> limitNutrients = {
  energyKey,
  'fat_g',
  'saturated_fat_g',
  'trans_fat_g',
  'sugars_g',
  'added_sugars_g',
  'salt_g',
  'sodium_mg',
  'cholesterol_mg',
};

/// Whether the daily amount of [nutrient] is a most (see
/// [limitNutrients]).
bool isLimitNutrient(String nutrient) => limitNutrients.contains(nutrient);
