// SPDX-License-Identifier: GPL-3.0-or-later

/// Showing body measurements in metric or imperial units.
///
/// The data is always metric (kilograms, centimetres), so an analysis
/// never mixes units; only what is shown and typed changes.
library;

import 'number_input.dart';

/// Whether measurements are shown in imperial units (pounds, feet and
/// inches) rather than metric. Set from the user's setting when the app
/// starts and whenever it changes, like `showTimesIn24Hours`.
bool showImperialUnits = false;

/// Kilograms in one pound, by definition.
const double kilogramsPerPound = 0.45359237;

/// Centimetres in one inch, by definition.
const double centimetresPerInch = 2.54;

/// The unit weights are typed and shown in: `kg` or `lb`.
String get weightUnit => showImperialUnits ? 'lb' : 'kg';

/// [kilograms] in the unit shown, as a number: kilograms, or pounds.
double weightInShownUnit(double kilograms) =>
    showImperialUnits ? kilograms / kilogramsPerPound : kilograms;

/// A weight typed in the unit shown, turned into kilograms for the data.
double kilogramsFromShown(double shown) =>
    showImperialUnits ? shown * kilogramsPerPound : shown;

/// [kilograms] for people, in the unit shown, to a tenth: `76.5 kg` or
/// `168.7 lb`.
String formatWeight(double kilograms) =>
    '${formatAmount(roundToTenth(weightInShownUnit(kilograms)))} $weightUnit';

/// [centimetres] as whole feet and inches: (5, 10) for 178 cm.
(int, int) feetAndInches(double centimetres) {
  final inches = (centimetres / centimetresPerInch).round();
  return (inches ~/ 12, inches % 12);
}

/// Feet and inches turned into centimetres for the data.
double centimetresFrom(int feet, double inches) =>
    (feet * 12 + inches) * centimetresPerInch;
