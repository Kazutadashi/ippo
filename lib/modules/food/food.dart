// SPDX-License-Identifier: GPL-3.0-or-later

/// A food in the user's food list.
library;

import '../../core/events/things.dart';
import 'nutrients.dart';

/// The units a food can be measured in.
const List<String> foodUnits = ['g', 'ml'];

/// The longest name allowed for a food, in characters.
const int maximumFoodNameLength = 100;

/// A food, such as "Rolled oats", with its nutrients per 100 g or 100 ml.
///
/// Created by `food_created`. See `docs/data-format.md`, section
/// "Module: food".
class Food {
  /// Creates a food.
  const Food({
    required this.id,
    required this.name,
    required this.measuredIn,
    required this.nutrientsPer100,
    required this.isDeleted,
  });

  /// Reads a food from its collected events. Returns null if the data is
  /// not a valid food (for example written by a broken tool).
  static Food? fromRecord(ThingRecord record) {
    final fields = record.fields;
    final name = fields['name'];
    final measuredIn = fields['measured_in'];
    final nutrientsPer100 = Nutrients.fromJson(fields['nutrients_per_100']);
    if (name is! String || name.trim().isEmpty) {
      return null;
    }
    if (measuredIn is! String || !foodUnits.contains(measuredIn)) {
      return null;
    }
    if (nutrientsPer100 == null) {
      return null;
    }
    return Food(
      id: record.id,
      name: name,
      measuredIn: measuredIn,
      nutrientsPer100: nutrientsPer100,
      isDeleted: record.isDeleted,
    );
  }

  /// The food's id.
  final String id;

  /// The food's name.
  final String name;

  /// `g` for grams or `ml` for millilitres.
  final String measuredIn;

  /// The nutrients in 100 g or 100 ml.
  final Nutrients nutrientsPer100;

  /// Whether the food was deleted. Entries that used it keep their own
  /// copy of its name and nutrients.
  final bool isDeleted;

  /// The nutrients in [amount] grams or millilitres of this food.
  Nutrients nutrientsFor(double amount) =>
      nutrientsPer100.scaledBy(amount / 100);
}

/// Checks a food name the user typed. Returns null if it is fine, or a
/// message explaining what is wrong.
String? checkFoodName(String name) {
  if (name.trim().isEmpty) {
    return 'Please enter a name.';
  }
  if (name.trim().length > maximumFoodNameLength) {
    return 'Please use at most $maximumFoodNameLength characters.';
  }
  return null;
}
