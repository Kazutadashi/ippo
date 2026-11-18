// SPDX-License-Identifier: GPL-3.0-or-later

/// A food's serving size from its label, such as "9 chips (28 g)".
library;

import '../../core/number_input.dart';

/// The longest unit name allowed, such as "chips" or "slices".
const int maximumUnitNameLength = 30;

/// A serving size: [count] pieces called [unit] weigh [amount] grams (or
/// millilitres). For "9 chips (28 g)": unit `chips`, count 9, amount 28.
///
/// It lets amounts be entered in the label's own unit ("9 chips") as
/// well as in grams. See `serving` in "Module: food" of
/// `docs/data-format.md`.
class FoodServing {
  /// Creates a serving size.
  const FoodServing({
    required this.unit,
    required this.count,
    required this.amount,
  });

  /// Reads a serving size from event data. Returns null if it is missing
  /// or not valid.
  static FoodServing? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final unit = json['unit'];
    final count = json['count'];
    final amount = json['amount'];
    if (unit is! String || unit.trim().isEmpty) {
      return null;
    }
    if (count is! num || count <= 0 || amount is! num || amount <= 0) {
      return null;
    }
    return FoodServing(
      unit: unit,
      count: count.toDouble(),
      amount: amount.toDouble(),
    );
  }

  /// The name of one piece, as on the label: `chips`, `slices`, `cups`.
  final String unit;

  /// How many pieces are in one serving: 9 for "9 chips".
  final double count;

  /// How many grams (or millilitres) one serving weighs: 28.
  final double amount;

  /// The grams (or millilitres) in one piece.
  double get amountPerUnit => amount / count;

  /// Turns [units] pieces into grams (or millilitres).
  double unitsToAmount(double units) => units * amountPerUnit;

  /// Turns grams (or millilitres) into pieces.
  double amountToUnits(double amount) => amount / amountPerUnit;

  /// Turns the serving size into event data.
  Map<String, Object?> toJson() => {
    'unit': unit.trim(),
    'count': jsonNumber(count),
    'amount': jsonNumber(amount),
  };

  /// Describes the serving size, for example `9 chips (28 g)`.
  String describe(String measuredIn) =>
      '${formatAmount(count)} $unit (${formatAmount(amount)} $measuredIn)';
}
