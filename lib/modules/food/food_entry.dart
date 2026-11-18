// SPDX-License-Identifier: GPL-3.0-or-later

/// One thing eaten, and the meals it can belong to.
library;

import '../../core/dates.dart';
import '../../core/events/things.dart';
import 'food.dart';
import 'nutrients.dart';

/// The meals an entry can belong to. The names are stored in the data
/// and must never change.
///
/// The app no longer asks for a meal (entries are simply listed in the
/// order they were eaten), but entries saved earlier, or by other tools,
/// may still have one, so it is still read.
enum Meal {
  /// Breakfast.
  breakfast('Breakfast'),

  /// Lunch.
  lunch('Lunch'),

  /// Dinner.
  dinner('Dinner'),

  /// A snack between meals.
  snack('Snack');

  const Meal(this.label);

  /// The meal's name on screen.
  final String label;

  /// Finds the meal stored as [name], or null if there is none.
  static Meal? fromName(Object? name) {
    for (final meal in Meal.values) {
      if (meal.name == name) {
        return meal;
      }
    }
    return null;
  }
}

/// One thing eaten. Created by `food_entry_recorded`.
///
/// The name and nutrients are copies made when the entry was logged, so
/// later changes to the food do not change past days.
class FoodEntry {
  /// Creates an entry.
  const FoodEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.meal,
    required this.foodId,
    required this.name,
    required this.amount,
    required this.measuredIn,
    required this.nutrients,
    required this.note,
    required this.isDeleted,
    required this.unitCount,
    required this.unitName,
  });

  /// Reads an entry from its collected events. Returns null if the data
  /// is not a valid entry.
  static FoodEntry? fromRecord(ThingRecord record) {
    final fields = record.fields;
    final date = fields['date'];
    final name = fields['name'];
    final nutrients = Nutrients.fromJson(fields['nutrients']);
    if (date is! String || !isValidDate(date)) {
      return null;
    }
    if (name is! String || nutrients == null) {
      return null;
    }

    final time = fields['time'];
    final foodId = fields['food_id'];
    final amount = fields['amount'];
    final measuredIn = fields['measured_in'];
    final note = fields['note'];
    final unitCount = fields['unit_count'];
    final unitName = fields['unit_name'];
    final hasUnits = unitCount is num && unitCount > 0 && unitName is String;
    return FoodEntry(
      id: record.id,
      date: date,
      // Optional fields with the wrong type are treated as missing.
      time: time is String && isValidTimeOfDay(time) ? time : null,
      meal: Meal.fromName(fields['meal']),
      foodId: foodId is String ? foodId : null,
      name: name,
      amount: amount is num && amount >= 0 ? amount.toDouble() : null,
      measuredIn: measuredIn is String && foodUnits.contains(measuredIn)
          ? measuredIn
          : null,
      nutrients: nutrients,
      note: note is String ? note : null,
      isDeleted: record.isDeleted,
      unitCount: hasUnits ? unitCount.toDouble() : null,
      unitName: hasUnits ? unitName : null,
    );
  }

  /// The entry's id.
  final String id;

  /// The day the entry counts for, `YYYY-MM-DD`.
  final String date;

  /// When it was eaten, `HH:MM`, if known.
  final String? time;

  /// The meal, if given.
  final Meal? meal;

  /// The food it was made from, or null for a quick entry.
  final String? foodId;

  /// The food's name when logged.
  final String name;

  /// How much, in [measuredIn] units, if known.
  final double? amount;

  /// `g` or `ml`, if known.
  final String? measuredIn;

  /// The nutrients for this amount.
  final Nutrients nutrients;

  /// A note, if any.
  final String? note;

  /// Whether the entry was deleted.
  final bool isDeleted;

  /// How many pieces were eaten, if entered in the label's unit (9 for
  /// "9 chips"). [amount] still holds the grams.
  final double? unitCount;

  /// The name of those pieces, such as `chips`, if entered that way.
  final String? unitName;

  /// Whether this is a quick entry (typed in directly, without a food).
  bool get isQuickEntry => amount == null;

  /// The grams (or ml) in one piece, if the entry was typed in pieces.
  double? get amountPerUnit {
    final pieces = unitCount;
    final grams = amount;
    if (pieces == null || pieces == 0 || grams == null) {
      return null;
    }
    return grams / pieces;
  }
}
