// SPDX-License-Identifier: GPL-3.0-or-later

/// Saving changes in the food module, as events.
///
/// Every change the food screens make goes through this class, so the
/// event types and fields written are all in one place. They follow
/// `docs/data-format.md`, section "Module: food".
library;

import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/number_input.dart';
import 'food.dart';
import 'food_diary.dart';
import 'food_entry.dart';
import 'food_serving.dart';
import 'nutrients.dart';

/// Writes the food module's events through [appState].
///
/// Every method throws `DataFolderException` if the event cannot be
/// saved; nothing is saved then.
class FoodActions {
  /// Creates the actions for [appState].
  FoodActions(this.appState);

  /// The app state that writes the events.
  final AppState appState;

  /// Adds a new food to the food list. Returns the event, whose id is
  /// the new food's id.
  ///
  /// [serving] is the label's serving size, such as "9 chips (28 g)", if
  /// known.
  Future<Event> createFood({
    required String name,
    required String measuredIn,
    required Nutrients nutrientsPer100,
    FoodServing? serving,
    String? ingredients,
  }) {
    final text = ingredients?.trim() ?? '';
    return _write('food_created', {
      'name': name.trim(),
      'measured_in': measuredIn,
      'nutrients_per_100': nutrientsPer100.toJson(),
      if (serving != null) 'serving': serving.toJson(),
      if (text.isNotEmpty) 'ingredients': text,
    });
  }

  /// Changes a food. Only the fields given are changed. Set
  /// [removeServing] to remove the serving size. Empty [ingredients]
  /// remove them.
  Future<Event> changeFood(
    String foodId, {
    String? name,
    Nutrients? nutrientsPer100,
    FoodServing? serving,
    bool removeServing = false,
    String? ingredients,
  }) {
    final text = ingredients?.trim();
    return _write('food_changed', {
      'target_id': foodId,
      'changes': {
        if (name != null) 'name': name.trim(),
        if (nutrientsPer100 != null)
          'nutrients_per_100': nutrientsPer100.toJson(),
        if (serving != null) 'serving': serving.toJson(),
        if (removeServing) 'serving': null,
        if (text != null) 'ingredients': text.isEmpty ? null : text,
      },
    });
  }

  /// Deletes a food. Entries that used it keep their own copy of its
  /// name and nutrients.
  Future<Event> deleteFood(String foodId) =>
      _write('food_deleted', {'target_id': foodId});

  /// Undoes [deleteFood].
  Future<Event> restoreFood(String foodId) =>
      _write('food_restored', {'target_id': foodId});

  /// Records eating [amount] of [food] on [date].
  ///
  /// The food's name and the nutrients for this amount are copied into
  /// the entry.
  ///
  /// [amount] is always in grams (or millilitres). If the user typed the
  /// amount in the label's unit ("9 chips"), [unitCount] and [unitName]
  /// keep that too.
  Future<Event> recordFoodEntry({
    required String date,
    required String? time,
    required Food food,
    required double amount,
    double? unitCount,
    String? unitName,
  }) {
    return _write('food_entry_recorded', {
      'date': date,
      if (time != null) 'time': time,
      'food_id': food.id,
      'name': food.name,
      'amount': jsonNumber(roundToTenth(amount)),
      'measured_in': food.measuredIn,
      if (unitCount != null && unitName != null)
        'unit_count': jsonNumber(roundToTenth(unitCount)),
      if (unitCount != null && unitName != null) 'unit_name': unitName,
      'nutrients': food.nutrientsFor(amount).toJson(),
    });
  }

  /// Records a quick entry: a name and nutrients typed in directly,
  /// without a food from the list.
  Future<Event> recordQuickEntry({
    required String date,
    required String? time,
    required String name,
    required Nutrients nutrients,
  }) {
    return _write('food_entry_recorded', {
      'date': date,
      if (time != null) 'time': time,
      'name': name.trim(),
      'nutrients': nutrients.toJson(),
    });
  }

  /// Changes the amount of an entry made from a food.
  ///
  /// The nutrients are scaled from the entry's own copy, not from the
  /// food's current values, so a later fix to the food does not sneak
  /// into this entry.
  ///
  /// As when recording, [newAmount] is in grams; [unitCount] keeps the
  /// number of pieces if the amount was typed that way (null clears it).
  /// [time] is when it was eaten (`HH:MM`), or null if not known; it is
  /// only written when it changed.
  Future<Event> changeFoodEntryAmount(
    FoodEntry entry, {
    required double newAmount,
    double? unitCount,
    required String? time,
  }) {
    final oldAmount = entry.amount;
    final newNutrients = oldAmount == null || oldAmount == 0
        ? entry.nutrients
        : entry.nutrients.scaledBy(newAmount / oldAmount);
    final unitName = entry.unitName;
    final keepsUnits = unitCount != null && unitName != null;
    return _write('food_entry_changed', {
      'target_id': entry.id,
      'changes': {
        'amount': jsonNumber(roundToTenth(newAmount)),
        'unit_count': keepsUnits ? jsonNumber(roundToTenth(unitCount)) : null,
        'nutrients': newNutrients.toJson(),
        if (time != entry.time) 'time': time,
      },
    });
  }

  /// Changes the name, nutrients and time (`HH:MM`, or null if not
  /// known) of a quick entry. The time is only written when it changed.
  Future<Event> changeQuickEntry(
    FoodEntry entry, {
    required String name,
    required Nutrients nutrients,
    required String? time,
  }) {
    return _write('food_entry_changed', {
      'target_id': entry.id,
      'changes': {
        'name': name.trim(),
        'nutrients': nutrients.toJson(),
        if (time != entry.time) 'time': time,
      },
    });
  }

  /// Deletes an entry.
  Future<Event> deleteEntry(String entryId) =>
      _write('food_entry_deleted', {'target_id': entryId});

  /// Undoes [deleteEntry].
  Future<Event> restoreEntry(String entryId) =>
      _write('food_entry_restored', {'target_id': entryId});

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(module: foodModuleName, type: type, data: data);
  }
}
