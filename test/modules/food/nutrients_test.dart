// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [Nutrients].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/food/nutrients.dart';

void main() {
  test('reads known nutrients and ignores unknown ones', () {
    final nutrients = Nutrients.fromJson({
      'energy_kcal': 389,
      'proteins_g': 13.2,
      'added_in_a_later_version_g': 1,
    })!;

    expect(nutrients.energyKcal, 389);
    expect(nutrients.values, {'energy_kcal': 389.0, 'proteins_g': 13.2});
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
}
