// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [Nutrients].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/food/nutrients.dart';

void main() {
  test('keeps nutrients it does not list yet, and skips non-nutrients', () {
    final nutrients = Nutrients.fromJson({
      'energy_kcal': 389,
      'proteins_g': 13.2,
      // A nutrient from a later version: kept, so it can be added up.
      'vitamin_b5_mg': 1.5,
      // Not a nutrient name, or not a number: ignored.
      'brand': 'Oats Co',
      'biotin_ug': 'lots',
    })!;

    expect(nutrients.values, {
      'energy_kcal': 389.0,
      'proteins_g': 13.2,
      'vitamin_b5_mg': 1.5,
    });
    final kind = nutrientKindOf('vitamin_b5_mg')!;
    expect(kind.label, 'Vitamin b5');
    expect(kind.unit, 'mg');
    // Listed nutrients first, in label order, then the others.
    expect(nutrients.toJson().keys.toList(), [
      'energy_kcal',
      'proteins_g',
      'vitamin_b5_mg',
    ]);
  });

  test('energy is required', () {
    expect(Nutrients.fromJson({'proteins_g': 13.2}), isNull);
  });

  test('negative or non-number values are refused', () {
    expect(Nutrients.fromJson({'energy_kcal': -1}), isNull);
    expect(Nutrients.fromJson({'energy_kcal': '389'}), isNull);
    expect(Nutrients.fromJson({'energy_kcal': 389, 'fat_g': 'x'}), isNull);
    expect(Nutrients.fromJson('not an object'), isNull);
  });

  test('scaling gives the nutrients for an amount, rounded', () {
    const per100 = Nutrients({'energy_kcal': 389, 'proteins_g': 13.15});

    final in60 = per100.scaledBy(0.6);

    expect(in60.values, {'energy_kcal': 233.4, 'proteins_g': 7.9});
  });

  test('adding keeps nutrients known in only one side', () {
    const breakfast = Nutrients({'energy_kcal': 300, 'proteins_g': 10});
    const snack = Nutrients({'energy_kcal': 150.5, 'fat_g': 8});

    final total = breakfast.plus(snack);

    expect(total.values, {
      'energy_kcal': 450.5,
      'proteins_g': 10.0,
      'fat_g': 8.0,
    });
    expect(Nutrients.none.plus(snack).values, snack.values);
  });

  test('written JSON uses integers for whole numbers, in a fixed order', () {
    const nutrients = Nutrients({'fat_g': 6.5, 'energy_kcal': 280});

    final json = nutrients.toJson();

    expect(json.keys, ['energy_kcal', 'fat_g']);
    expect(json['energy_kcal'], isA<int>());
    expect(json['fat_g'], 6.5);
  });

  test('salt and sodium are worked out from each other, to add up days', () {
    const euLabel = Nutrients({'energy_kcal': 100, 'salt_g': 1.5});
    const usLabel = Nutrients({'energy_kcal': 100, 'sodium_mg': 400});
    expect(euLabel.withSaltAndSodium().values['sodium_mg'], 600);
    expect(usLabel.withSaltAndSodium().values['salt_g'], 1);
    // Both given: kept as given.
    const both = Nutrients({'energy_kcal': 1, 'salt_g': 1, 'sodium_mg': 380});
    expect(both.withSaltAndSodium().values['sodium_mg'], 380);
    // Neither: nothing is made up.
    expect(const Nutrients({'energy_kcal': 1}).withSaltAndSodium().values, {
      'energy_kcal': 1,
    });
    final day = euLabel.withSaltAndSodium().plus(usLabel.withSaltAndSodium());
    expect((day.values['salt_g'], day.values['sodium_mg']), (2.5, 1000));
  });
}
