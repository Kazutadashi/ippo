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
  Future<Event> createFood({
    required String name,
    required String measuredIn,
    required Nutrients nutrientsPer100,
  }) {
    return _write('food_created', {
      'name': name.trim(),
      'measured_in': measuredIn,
      'nutrients_per_100': nutrientsPer100.toJson(),
    });
  }

  /// Changes a food. Only the fields given are changed.
  Future<Event> changeFood(
    String foodId, {
    String? name,
    Nutrients? nutrientsPer100,
  }) {
    return _write('food_changed', {
      'target_id': foodId,
      'changes': {
        if (name != null) 'name': name.trim(),
        if (nutrientsPer100 != null)
          'nutrients_per_100': nutrientsPer100.toJson(),
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
  Future<Event> recordFoodEntry({
    required String date,
    required String? time,
    required Meal meal,
    required Food food,
    required double amount,
  }) {
    return _write('food_entry_recorded', {
      'date': date,
      if (time != null) 'time': time,
      'meal': meal.name,
      'food_id': food.id,
      'name': food.name,
      'amount': jsonNumber(amount),
      'measured_in': food.measuredIn,
      'nutrients': food.nutrientsFor(amount).toJson(),
    });
  }

  /// Records a quick entry: a name and nutrients typed in directly,
  /// without a food from the list.
  Future<Event> recordQuickEntry({
    required String date,
    required String? time,
    required Meal meal,
    required String name,
    required Nutrients nutrients,
  }) {
    return _write('food_entry_recorded', {
      'date': date,
      if (time != null) 'time': time,
      'meal': meal.name,
      'name': name.trim(),
      'nutrients': nutrients.toJson(),
    });
  }

  /// Changes the amount and meal of an entry made from a food.
  ///
  /// The nutrients are scaled from the entry's own copy, not from the
  /// food's current values, so a later fix to the food does not sneak
  /// into this entry.
  Future<Event> changeFoodEntryAmount(
    FoodEntry entry, {
    required double newAmount,
    required Meal meal,
  }) {
    final oldAmount = entry.amount;
    final newNutrients = oldAmount == null || oldAmount == 0
        ? entry.nutrients
        : entry.nutrients.scaledBy(newAmount / oldAmount);
    return _write('food_entry_changed', {
      'target_id': entry.id,
      'changes': {
        'amount': jsonNumber(newAmount),
        'meal': meal.name,
        'nutrients': newNutrients.toJson(),
      },
    });
  }

  /// Changes the name, nutrients and meal of a quick entry.
  Future<Event> changeQuickEntry(
    FoodEntry entry, {
    required String name,
    required Nutrients nutrients,
    required Meal meal,
  }) {
    return _write('food_entry_changed', {
      'target_id': entry.id,
      'changes': {
        'name': name.trim(),
        'meal': meal.name,
        'nutrients': nutrients.toJson(),
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
