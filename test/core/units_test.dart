// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for showing body measurements in metric or imperial units.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/units.dart';

void main() {
  tearDown(() => showImperialUnits = false);

  test('weights are kept in kg and shown in the chosen unit', () {
    expect(formatWeight(76.5), '76.5 kg');
    showImperialUnits = true;
    expect(formatWeight(76.5), '168.7 lb');
    // What is typed in pounds is saved in kilograms.
    expect(kilogramsFromShown(100), closeTo(45.359237, 1e-9));
  });

  test('heights turn into feet and inches and back', () {
    expect(feetAndInches(178), (5, 10));
    expect(centimetresFrom(5, 10), closeTo(177.8, 1e-9));
  });
}
