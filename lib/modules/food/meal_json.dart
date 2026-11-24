// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading a whole meal pasted as JSON: several foods, each with its
/// label values and how much of it was eaten.
///
/// Each food is written exactly as for "Fill in from a label" (see
/// `label_json.dart` and `docs/food-labels.md`), plus `amount`: how much
/// was eaten, in grams (or millilitres for a drink):
///
/// ```json
/// {
///   "time": "12:30",
///   "foods": [
///     {
///       "name": "Potato chips",
///       "measured_in": "g",
///       "per": "serving",
///       "serving": {"unit": "chips", "count": 9, "amount": 28},
///       "nutrients": {"energy_kcal": 150, "fat_g": 9},
///       "amount": 46
///     }
///   ]
/// }
/// ```
///
/// `time` is optional. A plain list of foods, without the object around
/// it, works too.
library;

import 'dart:convert';

import '../../core/clock_time.dart';
import 'food_serving.dart';
import 'label_json.dart';
import 'nutrients.dart';
import 'nutrition_label.dart';

/// One food of a pasted meal, and how much of it was eaten.
class MealItem {
  /// Creates an item.
  const MealItem({
    required this.label,
    required this.amount,
    required this.nutrientsPer100,
  });

  /// The food's label, as read.
  final LabelReading label;

  /// How much was eaten, in the food's unit (g or ml).
  final double amount;

  /// The food's values per 100 g (or ml), worked out from the label.
  final Nutrients nutrientsPer100;

  /// The food's name.
  String get name => label.name!;

  /// `g` or `ml`.
  String get measuredIn => label.measuredIn;

  /// The label's serving size, if it gave one.
  FoodServing? get serving => label.serving;

  /// The nutrients in the amount eaten.
  Nutrients get eaten => nutrientsPer100.scaledBy(amount / 100);
}

/// What a pasted meal reads as: the foods that can be logged, and a
/// plain sentence for each one that cannot, so nothing is skipped
/// silently.
class MealReading {
  /// Creates a reading.
  const MealReading({required this.items, required this.problems, this.time});

  /// The foods that can be logged, in the order pasted.
  final List<MealItem> items;

  /// What is wrong with the others, such as "Cherries: no amount eaten".
  final List<String> problems;

  /// When the meal was eaten, if the paste said (`"time": "12:30"`).
  final ClockTime? time;
}

/// Reads [text] as a meal in JSON, or returns null if it is not one.
///
/// As for a single label, text around the JSON (a sentence, a ```json
/// block) is ignored: only the part from the first `{` or `[` to the
/// matching last `}` or `]` is read.
MealReading? readMealJson(String text) {
  final json = _decode(text);
  final List<Object?> foods;
  ClockTime? time;
  if (json is List<Object?>) {
    foods = json;
  } else if (json is Map<String, Object?> && json['foods'] is List) {
    foods = json['foods']! as List<Object?>;
    time = _clockTime(json['time']);
  } else {
    return null;
  }

  final items = <MealItem>[];
  final problems = <String>[];
  for (final (index, food) in foods.indexed) {
    if (food is! Map<String, Object?>) {
      problems.add('Food ${index + 1} is not written as a food.');
      continue;
    }
    final result = _readItem(food, index + 1);
    if (result.item != null) {
      items.add(result.item!);
    } else {
      problems.add(result.problem!);
    }
  }
  return MealReading(items: items, problems: problems, time: time);
}

/// Reads one food of the meal: the item, or what is wrong with it.
({MealItem? item, String? problem}) _readItem(
  Map<String, Object?> json,
  int number,
) {
  final label = labelFromJson(json, alsoKnown: const {'amount'});
  final name = label.name ?? 'Food $number';
  if (label.name == null) {
    return (item: null, problem: '$name has no name.');
  }
  final amount = labelNumber(json['amount']);
  if (amount == null || amount == 0) {
    return (item: null, problem: '$name: no amount eaten.');
  }
  if (!label.nutrients.containsKey(energyKey)) {
    return (item: null, problem: '$name: no energy (kcal).');
  }
  final per100 = nutrientsPer100From(
    label.nutrients,
    isPer100: label.isPer100,
    serving: label.serving,
  );
  if (per100 == null) {
    return (
      item: null,
      problem:
          '$name: the values are per serving, but no serving size '
          'says how much a serving is.',
    );
  }
  return (
    item: MealItem(label: label, amount: amount, nutrientsPer100: per100),
    problem: null,
  );
}

/// The JSON in [text], from the first `{` or `[` to the last `}` or `]`,
/// or null if there is none.
Object? _decode(String text) {
  final starts = [text.indexOf('{'), text.indexOf('[')]
    ..removeWhere((index) => index < 0);
  if (starts.isEmpty) {
    return null;
  }
  final start = starts.reduce((a, b) => a < b ? a : b);
  final end = text[start] == '['
      ? text.lastIndexOf(']')
      : text.lastIndexOf('}');
  if (end < start) {
    return null;
  }
  try {
    return jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    return null;
  }
}

/// [value] as a clock time if it is `HH:MM` (or `H:MM`), else null.
ClockTime? _clockTime(Object? value) {
  if (value is! String) {
    return null;
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) {
    return null;
  }
  return ClockTime(hour, minute);
}

/// The text that "Copy the format" puts on the clipboard for a meal:
/// instructions an AI assistant can follow to turn label photos and the
/// amounts eaten into JSON this reader understands. The rules for each
/// food are those of [labelJsonPrompt], so they never drift apart.
String mealJsonPrompt() {
  final oneFood = labelJsonPrompt()
      .split('\n')
      .skipWhile((line) => !line.startsWith('Rules:'))
      .skip(1)
      .join('\n');
  return '''
I will send photos of nutrition labels and how much I ate of each food. Turn them into JSON. Reply with only the JSON, in this shape:

{
  "time": "12:30",
  "foods": [
    {
      "name": "Potato chips",
      "measured_in": "g",
      "per": "serving",
      "serving": {"unit": "chips", "count": 9, "amount": 28},
      "nutrients": {"energy_kcal": 150, "fat_g": 9, "carbohydrates_g": 15, "proteins_g": 2, "sodium_mg": 170},
      "ingredients": "Potatoes, sunflower oil, salt.",
      "amount": 46
    }
  ]
}

Rules:
- One entry in "foods" per food I ate, in the order I list them.
- "amount": how much I ate of that food, in its measured_in units (grams, or millilitres for drinks), as a plain number.
- "time": when I ate, as HH:MM in 24 hours, only if I tell you; otherwise leave it out.
$oneFood''';
}
