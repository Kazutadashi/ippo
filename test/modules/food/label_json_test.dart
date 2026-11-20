// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [readLabelJson] and [labelJsonPrompt].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/food/label_json.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/food/nutrition_label.dart';

void main() {
  test('reads the JSON format, per serving', () {
    final reading = readLabelJson('''
{
  "name": "Potato chips",
  "measured_in": "g",
  "per": "serving",
  "serving": {"unit": "chips", "count": 9, "amount": 28},
  "nutrients": {"energy_kcal": 150, "fat_g": 9, "sodium_mg": 170},
  "ingredients": "Potatoes, sunflower oil, salt."
}''')!;

    expect(reading.name, 'Potato chips');
    expect(reading.isPer100, isFalse);
    expect(reading.serving!.unit, 'chips');
    expect(reading.serving!.count, 9);
    expect(reading.serving!.amount, 28);
    // Salt is worked out from sodium, as for label text.
    expect(reading.nutrients, {
      'energy_kcal': 150.0,
      'fat_g': 9.0,
      'sodium_mg': 170.0,
      'salt_g': 0.4,
    });
    expect(reading.ingredients, 'Potatoes, sunflower oil, salt.');
    expect(reading.unusedNames, isEmpty);
  });

  test('reads JSON inside a code block and a sentence', () {
    final reading = readLabelJson(
      'Sure! Here it is:\n```json\n'
      '{"per": "100 ml", "measured_in": "ml", '
      '"nutrients": {"energy_kj": 1046}}\n```\nAnything else?',
    )!;

    expect(reading.isPer100, isTrue);
    expect(reading.measuredIn, 'ml');
    // 1046 kJ is 250 kcal.
    expect(reading.nutrients, {'energy_kcal': 250.0});
  });

  test('a food_created event\'s data works too', () {
    final reading = readLabelJson(
      '{"name": "Rolled oats", "measured_in": "g", '
      '"nutrients_per_100": {"energy_kcal": 389, "proteins_g": 13.2}}',
    )!;

    expect(reading.isPer100, isTrue);
    expect(reading.nutrients, {'energy_kcal': 389.0, 'proteins_g': 13.2});
  });

  test('unknown names are listed, and bad values left out', () {
    final reading = readLabelJson(
      '{"brand": "Oats Co", "nutrients": {"energy_kcal": "389", '
      '"protien_g": 13, "fat_g": -1, "fiber_g": null, "salt_g": "1,5"}}',
    )!;

    // Numbers written as text are read; negative or missing ones are not.
    expect(reading.nutrients, {'energy_kcal': 389.0, 'salt_g': 1.5});
    expect(reading.unusedNames, ['brand', 'protien_g']);
  });

  test('text that is not label JSON is left to the text reader', () {
    expect(readLabelJson('Calories 150\nFat 9 g'), isNull);
    expect(readLabelJson('{"not": "a label"}'), isNull);
    expect(readLabelJson('{broken'), isNull);
    expect(readLabelJson('[1, 2]'), isNull);

    // readNutritionLabel then reads it as text.
    final reading = readNutritionLabel('Calories 150 {see note}\nFat 9 g');
    expect(reading.nutrients, {'energy_kcal': 150.0, 'fat_g': 9.0});
  });

  test('the copied instructions name every nutrient', () {
    final prompt = labelJsonPrompt();
    for (final kind in allNutrientKinds) {
      expect(prompt, contains(kind.key));
    }
  });

  test('the example in the instructions reads correctly', () {
    final prompt = labelJsonPrompt();
    final example = prompt.substring(
      prompt.indexOf('{'),
      prompt.indexOf('Rules:'),
    );
    final reading = readLabelJson(example)!;
    expect(reading.name, 'Potato chips');
    expect(reading.nutrients[energyKey], 150);
    expect(reading.unusedNames, isEmpty);
  });
}
