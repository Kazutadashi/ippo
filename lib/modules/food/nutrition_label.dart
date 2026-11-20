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
/// and the simple `name: value` format in `docs/food-labels.md`:
///
/// ```
/// name: Potato chips
/// serving: 9 chips = 28 g
/// calories: 150
/// fat: 9 g
/// ```
///
/// JSON (see `label_json.dart`) is tried first; this reader is for
/// everything else. It reads line by line and never guesses: a line it
/// does not recognise is ignored.
library;

import '../../core/number_input.dart';
import 'food_serving.dart';
import 'label_json.dart';
import 'label_reading.dart';
import 'nutrients.dart';

export 'label_reading.dart';

/// Which words on a line mean which nutrient, and the unit its field
/// is in. Checked in this order, so the more specific words come first:
/// "monounsaturated" before "saturated", "added sugars" before "sugars",
/// "vitamin b12" before "vitamin b1", and every kind of fat before "fat".
const List<(List<String>, String)> _nutrientWords = [
  (['trans'], 'trans_fat_g'),
  (['monounsaturat'], 'monounsaturated_fat_g'),
  (['polyunsaturat'], 'polyunsaturated_fat_g'),
  (['saturated', 'saturates'], 'saturated_fat_g'),
  (['cholesterol'], 'cholesterol_mg'),
  (['added sugar'], 'added_sugars_g'),
  (['sugar'], 'sugars_g'),
  (['fiber', 'fibre'], 'fiber_g'),
  (['protein'], 'proteins_g'),
  (['carbohydrate', 'carbs', 'carb'], 'carbohydrates_g'),
  (['fat'], 'fat_g'),
  (['salt'], 'salt_g'),
  (['sodium'], 'sodium_mg'),
  (['potassium'], 'potassium_mg'),
  (['calcium'], 'calcium_mg'),
  (['iron'], 'iron_mg'),
  (['magnesium'], 'magnesium_mg'),
  (['zinc'], 'zinc_mg'),
  (['phosphorus'], 'phosphorus_mg'),
  (['vitamin b12', 'cobalamin'], 'vitamin_b12_ug'),
  (['vitamin b6'], 'vitamin_b6_mg'),
  (['thiamin', 'vitamin b1'], 'thiamin_mg'),
  (['riboflavin', 'vitamin b2'], 'riboflavin_mg'),
  (['niacin', 'vitamin b3'], 'niacin_mg'),
  (['folate', 'folic acid', 'vitamin b9'], 'folate_ug'),
  (['vitamin a'], 'vitamin_a_ug'),
  (['vitamin c'], 'vitamin_c_mg'),
  (['vitamin d'], 'vitamin_d_ug'),
  (['vitamin e'], 'vitamin_e_mg'),
  (['vitamin k'], 'vitamin_k_ug'),
];

/// Lines with these words are about something Ippo does not track (or
/// would be mistaken for something it does), so they are skipped.
const List<String> _skippedWords = ['from fat', 'alcohol', 'daily value'];

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

/// Reads [text]: a label as JSON (see [readLabelJson]), or else the
/// words of a nutrition label, line by line.
LabelReading readNutritionLabel(String text) {
  final fromJson = readLabelJson(text);
  if (fromJson != null) {
    return fromJson;
  }
  String? name;
  FoodServing? serving;
  var measuredIn = 'g';
  final lowerText = text.toLowerCase();
  final isPer100 = RegExp(r'(per|/)\s*100\s*(g|ml)').hasMatch(lowerText);
  if (RegExp(r'100\s*ml').hasMatch(lowerText)) {
    measuredIn = 'ml';
  }
  final nutrients = <String, double>{};
  // The ingredients run from "Ingredients:" to the next empty line.
  final ingredients = <String>[];
  var isReadingIngredients = false;

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    final lower = line.toLowerCase();
    if (line.isEmpty) {
      isReadingIngredients = false;
      continue;
    }
    if (lower.startsWith('ingredients')) {
      isReadingIngredients = true;
      final colon = line.indexOf(':');
      final rest = colon < 0 ? '' : line.substring(colon + 1).trim();
      if (rest.isNotEmpty) {
        ingredients.add(rest);
      }
      continue;
    }
    if (isReadingIngredients) {
      ingredients.add(line);
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
    for (final (words, key) in _nutrientWords) {
      final word = words.where(lower.contains).firstOrNull;
      if (word == null) {
        continue;
      }
      final amount = _readAmount(lower, word, nutrientKindOf(key)!.unit);
      // The first matching line wins (for example "Total Sugars" before
      // a later line repeating sugars).
      if (amount != null && !nutrients.containsKey(key)) {
        nutrients[key] = amount;
      }
      break;
    }
  }

  // Labels in the US give sodium, not salt. Salt is 2.5 times sodium.
  final sodium = nutrients['sodium_mg'];
  if (!nutrients.containsKey('salt_g') && sodium != null) {
    nutrients['salt_g'] = roundToTenth(sodium * 2.5 / 1000);
  }

  return LabelReading(
    name: name == null || name.isEmpty ? null : name,
    serving: serving,
    measuredIn: measuredIn,
    isPer100: isPer100,
    nutrients: nutrients,
    ingredients: ingredients.isEmpty ? null : ingredients.join(' '),
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

/// Reads the amount on a nutrient line, in [unit] (`g`, `mg` or `µg`).
///
/// The number after the nutrient's [word] is read first ("Vitamin B12
/// 2.4 mcg", where the 12 is part of the name), else the first number on
/// the line ("Includes 10 g Added Sugars"). A unit after the number
/// (g, mg, mcg or µg) is turned into [unit]; without one, the number is
/// taken to be in [unit] already. A number followed by % is a share of
/// a daily value, not an amount, so it is never read as one.
double? _readAmount(String lower, String word, String unit) {
  final afterWord = lower.substring(lower.indexOf(word) + word.length);
  final withoutWord = lower.replaceFirst(word, ' ');
  for (final text in [afterWord, withoutWord]) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(mcg|µg|ug|mg|g|%)?')
        .firstMatch(text);
    if (match == null) {
      continue;
    }
    final found = match.group(2);
    if (found == '%') {
      // A share of a daily value; the amount may be elsewhere on the
      // line ("Includes 0g Added Sugars 0%").
      continue;
    }
    final value = _toNumber(match.group(1)!);
    return _convert(value, from: found ?? unit, to: unit);
  }
  return null;
}

/// [value] in [from] (g, mg, mcg, µg or ug) turned into [to].
double _convert(double value, {required String from, required String to}) {
  double inMicrograms(String unit) => switch (unit) {
    'g' => 1000000,
    'mg' => 1000,
    _ => 1,
  };
  return value * inMicrograms(from) / inMicrograms(to);
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
