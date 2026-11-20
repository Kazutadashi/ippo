// SPDX-License-Identifier: GPL-3.0-or-later

/// What was read from a pasted nutrition label.
library;

import 'food_serving.dart';

/// What was read from a label's text or JSON.
class LabelReading {
  /// Creates a reading.
  const LabelReading({
    required this.name,
    required this.serving,
    required this.measuredIn,
    required this.isPer100,
    required this.nutrients,
    this.ingredients,
    this.unusedNames = const [],
  });

  /// The food's name, if the text gave one (`name: ...`).
  final String? name;

  /// The serving size, if the text gave one.
  final FoodServing? serving;

  /// `g` or `ml`.
  final String measuredIn;

  /// Whether the values are per 100 g (or ml) rather than per serving.
  final bool isPer100;

  /// The values found, by nutrient field name (see `nutrients.dart`).
  final Map<String, double> nutrients;

  /// The ingredients, as written after "Ingredients:", if given.
  final String? ingredients;

  /// Names in pasted JSON that Ippo does not know, so they were left
  /// out, such as a misspelt nutrient. Shown, so nothing is dropped
  /// silently.
  final List<String> unusedNames;

  /// Whether anything useful was found.
  bool get isEmpty =>
      serving == null &&
      nutrients.isEmpty &&
      name == null &&
      ingredients == null;
}
