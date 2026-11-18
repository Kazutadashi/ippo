// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading numbers the user typed, and showing numbers on screen.
library;

/// Reads a number the user typed, such as `150`, `12.5` or `12,5`.
///
/// Both `.` and `,` are accepted as the decimal mark, because many
/// countries write `12,5`. Returns null if [text] is not a number, or if
/// it is negative (amounts and nutrients are never negative).
double? parseAmount(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  final number = double.tryParse(normalized);
  if (number == null || number.isNaN || number.isInfinite || number < 0) {
    return null;
  }
  return number;
}

/// Shows a number without needless decimals: `150`, `12.5`, `0.3`.
///
/// Numbers are rounded to one decimal place.
String formatAmount(double number) {
  final rounded = roundToTenth(number);
  if (rounded == rounded.roundToDouble()) {
    return rounded.round().toString();
  }
  return rounded.toStringAsFixed(1);
}

/// Rounds [number] to one decimal place, for example 12.345 to 12.3.
double roundToTenth(double number) => (number * 10).round() / 10;

/// Returns [value] in the form it should be written to a data file:
/// whole numbers as integers (`280`, not `280.0`), so files stay easy to
/// read.
num jsonNumber(double value) {
  return value == value.roundToDouble() ? value.round() : value;
}
