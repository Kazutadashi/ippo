// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [readMealJson] and [mealJsonPrompt].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/food/meal_json.dart';

void main() {
  test('reads each food with how much was eaten, and the time', () {
    final meal = readMealJson('''
Here is your meal:
```json
{
  "time": "12:30",
  "foods": [
    {"name": "Ham", "per": "100", "nutrients": {"energy_kcal": 110, "proteins_g": 21}, "amount": 39},
    {"name": "Crackers", "per": "serving",
     "serving": {"unit": "crackers", "count": 27, "amount": 30},
     "nutrients": {"energy_kcal": 150, "sodium_mg": 230}, "amount": 46}
  ]
}
```''')!;
    expect(meal.problems, isEmpty);
    expect(meal.items.map((item) => item.name), ['Ham', 'Crackers']);
    expect((meal.time!.hour, meal.time!.minute), (12, 30));
    final ham = meal.items[0];
    expect(ham.amount, 39);
    expect(ham.nutrientsPer100.energyKcal, 110);
    expect(ham.eaten.energyKcal, closeTo(42.9, 0.05));
    // Per serving turned into per 100 g: 150 kcal per 30 g is 500.
    final crackers = meal.items[1];
    expect(crackers.nutrientsPer100.energyKcal, 500);
    expect(crackers.eaten.energyKcal, 230);
  });

  test('a plain list works, without a time', () {
    final meal = readMealJson(
      '[{"name": "Cherries", "per": "100", '
      '"nutrients": {"energy_kcal": 63}, "amount": 86}]',
    )!;
    expect(meal.items.single.name, 'Cherries');
    expect(meal.time, isNull);
  });

  test('a food that cannot be logged is named with the reason', () {
    final meal = readMealJson('''
{"foods": [
  {"name": "Cheese", "per": "100", "nutrients": {"energy_kcal": 400}},
  {"name": "Bread", "per": "serving", "nutrients": {"energy_kcal": 80}, "amount": 30},
  {"name": "Water", "per": "100", "nutrients": {}, "amount": 250},
  {"per": "100", "nutrients": {"energy_kcal": 5}, "amount": 10},
  {"name": "Apple", "per": "100", "nutrients": {"energy_kcal": 52}, "amount": 180}
]}''')!;
    expect(meal.items.map((item) => item.name), ['Apple']);
    expect(meal.problems, [
      'Cheese: no amount eaten.',
      'Bread: the values are per serving, but no serving size says how '
          'much a serving is.',
      'Water: no energy (kcal).',
      'Food 4 has no name.',
    ]);
  });

  test('text that is not a meal is not read as one', () {
    expect(readMealJson('Calories 150'), isNull);
    expect(readMealJson('{"name": "One food", "nutrients": {}}'), isNull);
  });

  test('the copied format asks for an amount per food', () {
    final prompt = mealJsonPrompt();
    expect(prompt, contains('"amount": 46'));
    expect(prompt, contains('"foods"'));
    // The per-food rules come from the label format.
    expect(prompt, contains('"per": "serving" if the values are per serving'));
  });
}
