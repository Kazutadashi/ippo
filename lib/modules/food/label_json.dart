// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading a nutrition label written as JSON, the format AI assistants
/// and data tools handle best.
///
/// The JSON uses the same field names as Ippo's data (see `food_created`
/// in `docs/data-format.md`), so what you paste is what gets saved:
///
/// ```json
/// {
///   "name": "Potato chips",
///   "measured_in": "g",
///   "per": "serving",
///   "serving": {"unit": "chips", "count": 9, "amount": 28},
///   "nutrients": {"energy_kcal": 150, "fat_g": 9, "sodium_mg": 170},
///   "ingredients": "Potatoes, sunflower oil, salt."
/// }
/// ```
///
/// A `food_created` event's data (with `nutrients_per_100`) also works,
/// so a food can be copied from one data folder into another.
library;

import 'dart:convert';

import '../../core/number_input.dart';
import 'food_serving.dart';
import 'label_reading.dart';
import 'nutrients.dart';

/// The top-level names this reader understands. Anything else is listed
/// in [LabelReading.unusedNames].
const List<String> _knownNames = [
  'name',
  'measured_in',
  'per',
  'serving',
  'nutrients',
  'nutrients_per_100',
  'ingredients',
];

/// Reads [text] as a label in JSON. Returns null if it is not JSON in
/// this shape, so the caller can read it as plain label text instead.
///
/// Assistants often wrap JSON in a ```json block or add a sentence
/// around it, so only the part from the first `{` to the last `}` is
/// read. Missing or empty values are left out; nothing is guessed.
LabelReading? readLabelJson(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end < start) {
    return null;
  }
  final Object? json;
  try {
    json = jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    return null;
  }
  if (json is! Map<String, Object?>) {
    return null;
  }
  // Some JSON that is not a label at all: let the text reader try.
  if (!_knownNames.any(json.containsKey)) {
    return null;
  }

  final unused = [
    for (final name in json.keys)
      if (!_knownNames.contains(name)) name,
  ];
  final measuredIn = json['measured_in'] == 'ml' ? 'ml' : 'g';

  // A food_created event's nutrients are always per 100.
  final per100Values = json['nutrients_per_100'];
  final bool isPer100;
  final Object? values;
  if (per100Values != null) {
    isPer100 = true;
    values = per100Values;
  } else {
    isPer100 = _saysPer100(json['per']);
    values = json['nutrients'];
  }

  final nutrients = _readNutrients(values, unused);
  final name = _text(json['name']);
  final ingredients = _text(json['ingredients']);
  return LabelReading(
    name: name,
    serving: FoodServing.fromJson(json['serving']),
    measuredIn: measuredIn,
    isPer100: isPer100,
    nutrients: nutrients,
    ingredients: ingredients,
    unusedNames: unused,
  );
}

/// Whether a `per` value means "per 100 g (or ml)": `"100"`, `"100g"`,
/// `"100 ml"` or the number 100. Anything else means per serving.
bool _saysPer100(Object? per) {
  if (per is num) {
    return per == 100;
  }
  return per is String && per.contains('100');
}

/// [value] if it is text that is not empty, else null.
String? _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

/// Reads the nutrients object. Names Ippo does not know are added to
/// [unused]. Energy in kJ is turned into kcal, and sodium into salt, as
/// for label text.
Map<String, double> _readNutrients(Object? values, List<String> unused) {
  final nutrients = <String, double>{};
  if (values is! Map<String, Object?>) {
    return nutrients;
  }
  final knownKeys = {for (final kind in allNutrientKinds) kind.key};
  for (final entry in values.entries) {
    if (entry.key == 'energy_kj') {
      // Read below, only if there is no energy in kcal.
      continue;
    }
    if (!knownKeys.contains(entry.key)) {
      unused.add(entry.key);
      continue;
    }
    final number = _number(entry.value);
    if (number != null) {
      nutrients[entry.key] = number;
    }
  }
  final kilojoules = _number(values['energy_kj']);
  if (!nutrients.containsKey(energyKey) && kilojoules != null) {
    // 1 kcal is 4.184 kJ.
    nutrients[energyKey] = roundToTenth(kilojoules / 4.184);
  }
  // Labels in the US give sodium, not salt. Salt is 2.5 times sodium.
  final sodium = nutrients['sodium_mg'];
  if (!nutrients.containsKey('salt_g') && sodium != null) {
    nutrients['salt_g'] = roundToTenth(sodium * 2.5 / 1000);
  }
  return nutrients;
}

/// [value] as a number, if it is one that is not negative. Numbers
/// written as text ("9", "1,5") are read too; null means "not given".
double? _number(Object? value) {
  final double? number;
  if (value is num) {
    number = value.toDouble();
  } else if (value is String) {
    number = double.tryParse(value.trim().replaceAll(',', '.'));
  } else {
    number = null;
  }
  if (number == null || number < 0 || number.isNaN || number.isInfinite) {
    return null;
  }
  return number;
}

/// The text that "Copy the format" puts on the clipboard: instructions
/// an AI assistant can follow to turn a nutrition label into JSON this
/// reader understands. The list of nutrient names comes from
/// [allNutrientKinds], so it never falls behind the app.
String labelJsonPrompt() {
  final names = [
    for (final kind in allNutrientKinds) '${kind.key} (${kind.label})',
  ].join(', ');
  return '''
Turn this nutrition label into JSON. Reply with only the JSON, in this shape:

{
  "name": "Potato chips",
  "measured_in": "g",
  "per": "serving",
  "serving": {"unit": "chips", "count": 9, "amount": 28},
  "nutrients": {
    "energy_kcal": 150,
    "fat_g": 9,
    "saturated_fat_g": 1.5,
    "carbohydrates_g": 15,
    "sugars_g": 1,
    "fiber_g": 1,
    "proteins_g": 2,
    "sodium_mg": 170
  },
  "ingredients": "Potatoes, sunflower oil, salt."
}

Rules:
- "measured_in": "g" for solids, "ml" for drinks.
- "per": "serving" if the values are per serving, "100" if they are per 100 g or 100 ml. Use the column the label gives; do not convert.
- "serving": "count" pieces of "unit" weigh "amount" (in measured_in units). "2/3 cup (55 g)" is {"unit": "cup", "count": 0.667, "amount": 55}. With only a weight, use {"unit": "serving", "count": 1, "amount": 30}. Leave it out if the label has no serving size.
- "nutrients": each name ends in its unit (_g, _mg, _ug, _kcal). Give plain numbers in that unit. If energy is only in kJ, give "energy_kj" instead. Leave out anything the label does not show, and skip % daily values.
- Nutrient names: $names.
- "ingredients": as written on the label, or leave it out.''';
}
