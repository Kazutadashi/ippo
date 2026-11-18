// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading a nutrition label's text, so a new food can be filled in by
/// pasting instead of typing every number.
///
/// It understands typical label text in English, such as
///
/// ```
/// Serving size 9 chips (28g)        Nutrition per 100 g
/// Calories 150                      Energy 2010 kJ / 480 kcal
/// Total Fat 9g                      Fat 30 g
///   Saturated Fat 1.5g                of which saturates 3 g
/// Sodium 170mg                      Carbohydrate 50 g
/// Total Carbohydrate 15g              of which sugars 1 g
///   Dietary Fiber 1g                Fibre 4 g
///   Total Sugars 1g                 Protein 6 g
/// Protein 2g                        Salt 1.2 g
/// ```
///
/// and the simple format in `docs/food-labels.md`, which an assistant can
/// write from a photo of a label:
///
/// ```
/// name: Potato chips
/// serving: 9 chips = 28 g
/// calories: 150
/// fat: 9 g
/// ```
///
/// It reads line by line and never guesses: a line it does not
/// recognise is ignored.
library;

import '../../core/number_input.dart';
import 'food_serving.dart';
import 'nutrients.dart';

/// What was read from a label's text.
class LabelReading {
  /// Creates a reading.
  const LabelReading({
    required this.name,
    required this.serving,
    required this.measuredIn,
    required this.isPer100,
    required this.nutrients,
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

  /// Whether anything useful was found.
  bool get isEmpty => serving == null && nutrients.isEmpty && name == null;
}

/// Which words on a line mean which nutrient. Checked in this order, so
/// "saturated fat" is found before "fat" and "sugars" before
/// "carbohydrate".
const List<(List<String>, String)> _nutrientWords = [
  (['saturated', 'saturates'], 'saturated_fat_g'),
  (['sugar'], 'sugars_g'),
  (['fiber', 'fibre'], 'fiber_g'),
  (['protein'], 'proteins_g'),
  (['carbohydrate', 'carbs', 'carb'], 'carbohydrates_g'),
  (['fat'], 'fat_g'),
  (['salt'], 'salt_g'),
];

/// Lines with these words are about something Ippo does not track (or
/// would be mistaken for something it does), so they are skipped.
const List<String> _skippedWords = [
  'trans',
  'cholesterol',
  'from fat',
  'added',
  'unsaturat',
  'poly',
  'mono',
  'alcohol',
  'daily value',
];

/// Matches a number such as `9`, `1.5` or `1,5`.
final RegExp _number = RegExp(r'\d+(?:[.,]\d+)?');

/// Matches a serving size: "9 chips (28 g)", "9 chips = 28 g",
/// "2/3 cup (55g)". Groups: count (maybe a fraction), unit name, amount,
/// g or ml.
final RegExp _servingWithUnit = RegExp(
  r'(\d+(?:[.,]\d+)?(?:\s*/\s*\d+)?)\s*([a-z][a-z \-]*?)\s*[(=]\s*'
  r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
  caseSensitive: false,
);

/// Matches a serving size given only in grams: "28 g". Groups: amount,
/// g or ml.
final RegExp _servingGramsOnly = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
  caseSensitive: false,
);

/// Reads [text], the words of a nutrition label.
LabelReading readNutritionLabel(String text) {
  String? name;
  FoodServing? serving;
  var measuredIn = 'g';
  final lowerText = text.toLowerCase();
  final isPer100 = RegExp(r'(per|/)\s*100\s*(g|ml)').hasMatch(lowerText);
  if (RegExp(r'100\s*ml').hasMatch(lowerText)) {
    measuredIn = 'ml';
  }
  final nutrients = <String, double>{};
  double? sodiumMilligrams;

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    final lower = line.toLowerCase();
    if (line.isEmpty) {
      continue;
    }
    if (lower.startsWith('name:') || lower.startsWith('name =')) {
      name = line.substring(line.indexOf(RegExp('[:=]')) + 1).trim();
      continue;
    }
    if (lower.contains('serving')) {
      final found = _readServing(line);
      if (found != null) {
        serving = found.$1;
        measuredIn = found.$2;
      }
      continue;
    }
    if (_skippedWords.any(lower.contains)) {
      continue;
    }
    if (_isEnergyLine(lower)) {
      final kcal = _readKilocalories(lower);
      if (kcal != null) {
        nutrients[energyKey] = kcal;
      }
      continue;
    }
    if (lower.contains('sodium')) {
      sodiumMilligrams = _readMilligrams(lower);
      continue;
    }
    for (final (words, key) in _nutrientWords) {
      if (words.any(lower.contains)) {
        final grams = _readGrams(lower);
        // The first matching line wins (for example "Total Sugars" before
        // a later line repeating sugars).
        if (grams != null && !nutrients.containsKey(key)) {
          nutrients[key] = grams;
        }
        break;
      }
    }
  }

  // Labels in the US give sodium, not salt. Salt is 2.5 times sodium.
  if (!nutrients.containsKey('salt_g') && sodiumMilligrams != null) {
    nutrients['salt_g'] = roundToTenth(sodiumMilligrams * 2.5 / 1000);
  }

  return LabelReading(
    name: name == null || name.isEmpty ? null : name,
    serving: serving,
    measuredIn: measuredIn,
    isPer100: isPer100,
    nutrients: nutrients,
  );
}

/// Reads a serving size line. Returns the serving and its unit (g or
/// ml), or null.
(FoodServing, String)? _readServing(String line) {
  final withUnit = _servingWithUnit.firstMatch(line);
  if (withUnit != null) {
    final count = _toCount(withUnit.group(1)!);
    final unit = withUnit.group(2)!.trim();
    final amount = _toNumber(withUnit.group(3)!);
    // "serving" itself is not a useful unit ("1 serving (28 g)").
    final isRealUnit = !unit.toLowerCase().startsWith('serving');
    if (count > 0 && amount > 0 && isRealUnit) {
      return (
        FoodServing(unit: unit, count: count, amount: amount),
        withUnit.group(4)!.toLowerCase(),
      );
    }
  }
  final gramsOnly = _servingGramsOnly.firstMatch(line);
  if (gramsOnly != null) {
    final amount = _toNumber(gramsOnly.group(1)!);
    if (amount > 0) {
      return (
        FoodServing(unit: 'serving', count: 1, amount: amount),
        gramsOnly.group(2)!.toLowerCase(),
      );
    }
  }
  return null;
}

bool _isEnergyLine(String lower) =>
    lower.contains('calorie') ||
    lower.contains('energy') ||
    lower.contains('kcal') ||
    lower.contains('kj');

/// Reads the kilocalories on an energy line: the number before "kcal",
/// else a number in kJ turned into kcal, else the first number (as in
/// "Calories 150").
double? _readKilocalories(String lower) {
  final kcal = RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal').firstMatch(lower);
  if (kcal != null) {
    return _toNumber(kcal.group(1)!);
  }
  final kilojoules = RegExp(r'(\d+(?:[.,]\d+)?)\s*kj').firstMatch(lower);
  if (kilojoules != null) {
    // 1 kcal is 4.184 kJ.
    return roundToTenth(_toNumber(kilojoules.group(1)!) / 4.184);
  }
  return _firstNumber(lower);
}

/// Reads grams on a nutrient line: the first number, turned from mg if
/// it is followed by "mg".
double? _readGrams(String lower) {
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(mg|g)?').firstMatch(lower);
  if (match == null) {
    return null;
  }
  final value = _toNumber(match.group(1)!);
  return match.group(2) == 'mg' ? value / 1000 : value;
}

/// Reads milligrams on a sodium line: the first number, turned from
/// grams if it is followed by "g" alone.
double? _readMilligrams(String lower) {
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(mg|g)?').firstMatch(lower);
  if (match == null) {
    return null;
  }
  final value = _toNumber(match.group(1)!);
  return match.group(2) == 'g' ? value * 1000 : value;
}

double? _firstNumber(String text) {
  final match = _number.firstMatch(text);
  return match == null ? null : _toNumber(match.group(0)!);
}

double _toNumber(String text) => double.parse(text.replaceAll(',', '.'));

/// Reads a count that may be a fraction, such as `9`, `1.5` or `2/3`.
double _toCount(String text) {
  final parts = text.split('/');
  if (parts.length != 2) {
    return _toNumber(text);
  }
  final bottom = _toNumber(parts[1].trim());
  return bottom == 0 ? 0 : _toNumber(parts[0].trim()) / bottom;
}

/// Turns label values into nutrients per 100 g (or ml), the way foods
/// are stored. Values per serving are scaled by the serving's weight.
/// Returns null if the values are per serving but no serving weight is
/// known.
Nutrients? nutrientsPer100From(
  Map<String, double> values, {
  required bool isPer100,
  required FoodServing? serving,
}) {
  if (isPer100) {
    return Nutrients(values);
  }
  if (serving == null) {
    return null;
  }
  return Nutrients(values).scaledBy(100 / serving.amount);
}
