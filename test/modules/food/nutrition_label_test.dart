// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for reading nutrition labels from pasted text.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/food/food_serving.dart';
import 'package:ippo/modules/food/nutrition_label.dart';

void main() {
  test('a US label, values per serving', () {
    const text = '''
Nutrition Facts
8 servings per container
Serving size 9 chips (28g)
Amount per serving
Calories 150
% Daily Value*
Total Fat 9g 12%
  Saturated Fat 1.5g 8%
  Trans Fat 0g
Cholesterol 0mg 0%
Sodium 170mg 7%
Total Carbohydrate 15g 5%
  Dietary Fiber 1g 4%
  Total Sugars 1g
    Includes 0g Added Sugars 0%
Protein 2g
''';

    final reading = readNutritionLabel(text);

    expect(reading.isPer100, isFalse);
    expect(reading.measuredIn, 'g');
    expect(reading.serving!.unit, 'chips');
    expect(reading.serving!.count, 9);
    expect(reading.serving!.amount, 28);
    expect(reading.nutrients, {
      'energy_kcal': 150,
      'fat_g': 9,
      'saturated_fat_g': 1.5,
      'carbohydrates_g': 15,
      'fiber_g': 1,
      'sugars_g': 1,
      'proteins_g': 2,
      'trans_fat_g': 0,
      'cholesterol_mg': 0,
      'added_sugars_g': 0,
      'sodium_mg': 170,
      // 170 mg sodium is 0.425 g salt, rounded.
      'salt_g': 0.4,
    });
  });

  test('vitamins, minerals and ingredients are read too', () {
    const text = '''
Serving size 1 cup (240 mL)
Calories 110
Vitamin D 2.5mcg 10%
Calcium 300mg 25%
Iron 0.1mg 0%
Potassium 380mg 8%
Vitamin A 10%
Vitamin B12 1.2 mcg 50%
Riboflavin 0.4mg 30%

Ingredients: Milk, vitamin A palmitate,
vitamin D3.

Contains: milk.
''';

    final reading = readNutritionLabel(text);

    expect(reading.measuredIn, 'ml');
    expect(reading.nutrients, {
      'energy_kcal': 110,
      'vitamin_d_ug': 2.5,
      'calcium_mg': 300,
      'iron_mg': 0.1,
      'potassium_mg': 380,
      // "Vitamin A 10%" gives only a share of a daily value: not read.
      'vitamin_b12_ug': 1.2,
      'riboflavin_mg': 0.4,
    });
    expect(reading.ingredients, 'Milk, vitamin A palmitate, vitamin D3.');
  });

  test('a European label, values per 100 g', () {
    const text = '''
Nutrition information
Typical values per 100 g
Energy 2010 kJ / 480 kcal
Fat 30 g
of which saturates 3 g
Carbohydrate 50 g
of which sugars 1 g
Fibre 4 g
Protein 6 g
Salt 1.2 g
''';

    final reading = readNutritionLabel(text);

    expect(reading.isPer100, isTrue);
    expect(reading.serving, isNull);
    expect(reading.nutrients, {
      'energy_kcal': 480,
      'fat_g': 30,
      'saturated_fat_g': 3,
      'carbohydrates_g': 50,
      'sugars_g': 1,
      'fiber_g': 4,
      'proteins_g': 6,
      'salt_g': 1.2,
    });
  });

  test('the simple format, as an assistant would write it', () {
    const text = '''
name: Potato chips
serving: 9 chips = 28 g
calories: 150
fat: 9 g
saturated fat: 1.5 g
carbohydrates: 15 g
sugars: 1 g
fiber: 1 g
protein: 2 g
salt: 0.4 g
''';

    final reading = readNutritionLabel(text);

    expect(reading.name, 'Potato chips');
    expect(reading.serving!.describe('g'), '9 chips (28 g)');
    expect(reading.nutrients['energy_kcal'], 150);
    expect(reading.nutrients['salt_g'], 0.4);
    expect(reading.nutrients, hasLength(8));
  });

  test('energy only in kJ is turned into kcal', () {
    final reading = readNutritionLabel('per 100 g\nEnergy 2000 kJ');
    expect(reading.nutrients['energy_kcal'], 478);
  });

  test('a fraction serving size such as 2/3 cup', () {
    final reading = readNutritionLabel('Serving size 2/3 cup (55g)');
    expect(reading.serving!.unit, 'cup');
    expect(reading.serving!.count, closeTo(2 / 3, 1e-9));
    expect(reading.serving!.amount, 55);
  });

  test('a serving given only in grams', () {
    final reading = readNutritionLabel('Serving size: 30 g');
    expect(reading.serving!.unit, 'serving');
    expect(reading.serving!.count, 1);
    expect(reading.serving!.amount, 30);
  });

  test('drinks are measured in ml', () {
    final reading = readNutritionLabel(
      'Serving size 1 cup (240 mL)\nCalories 100',
    );
    expect(reading.measuredIn, 'ml');
    expect(reading.serving!.amount, 240);
  });

  test('commas as decimal marks are understood', () {
    final reading = readNutritionLabel('per 100 g\nFett 3,5 g\nfat 3,5 g');
    expect(reading.nutrients['fat_g'], 3.5);
  });

  test('text that is not a label gives nothing', () {
    final reading = readNutritionLabel('Remember to buy milk.');
    expect(reading.isEmpty, isTrue);
  });

  group('nutrientsPer100From', () {
    test('values per serving are scaled to 100 g', () {
      const serving = FoodServing(unit: 'chips', count: 9, amount: 28);
      final per100 = nutrientsPer100From(
        {'energy_kcal': 150, 'fat_g': 9},
        isPer100: false,
        serving: serving,
      )!;
      expect(per100.values, {'energy_kcal': 535.7, 'fat_g': 32.1});
    });

    test('values per serving need a serving weight', () {
      expect(
        nutrientsPer100From(
          {'energy_kcal': 150},
          isPer100: false,
          serving: null,
        ),
        isNull,
      );
    });
  });

  group('FoodServing', () {
    const chips = FoodServing(unit: 'chips', count: 9, amount: 28);

    test('converts pieces and grams both ways', () {
      expect(chips.unitsToAmount(9), 28);
      expect(chips.unitsToAmount(18), 56);
      expect(chips.amountToUnits(56), closeTo(18, 1e-9));
    });

    test('is written and read back', () {
      expect(chips.toJson(), {'unit': 'chips', 'count': 9, 'amount': 28});
      final read = FoodServing.fromJson(chips.toJson())!;
      expect(read.describe('g'), '9 chips (28 g)');
    });

    test('invalid data is refused', () {
      expect(FoodServing.fromJson({'unit': 'chips', 'count': 0}), isNull);
      expect(FoodServing.fromJson('9 chips'), isNull);
    });
  });

  test('a serving typed in one field', () {
    expect(readServingText('9 chips'), (count: 9.0, unit: 'chips'));
    expect(readServingText('slice'), (count: 1.0, unit: 'slice'));
    expect(readServingText('2'), (count: 2.0, unit: 'pieces'));
    expect(readServingText('2/3 cup')!.count, closeTo(2 / 3, 1e-9));
    expect(readServingText(''), isNull);
    expect(readServingText('0 chips'), isNull);
  });
}
