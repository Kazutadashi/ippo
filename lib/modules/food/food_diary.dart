// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module's current state, worked out from the event log.
library;

import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'food.dart';
import 'food_entry.dart';
import 'nutrients.dart';

/// The module's name in event files. Never change it.
const String foodModuleName = 'food';

/// All foods and food entries, with every change applied.
class FoodDiary {
  /// Creates a diary. Normal code uses [FoodDiary.fromEvents].
  FoodDiary({
    required this.foods,
    required this.entries,
    required this.invalidCount,
  });

  /// The current state for [appState], worked out once per change of
  /// the data and shared by every screen (see `AppState.derived`).
  static FoodDiary of(AppState appState) =>
      appState.derived('food_diary', FoodDiary.fromEvents);

  /// Builds the diary from the event log's events (oldest first).
  factory FoodDiary.fromEvents(List<Event> events) {
    final foodRecords = collectThings(
      events,
      module: foodModuleName,
      createdType: 'food_created',
      thingName: 'food',
    );
    final entryRecords = collectThings(
      events,
      module: foodModuleName,
      createdType: 'food_entry_recorded',
      thingName: 'food_entry',
    );

    var invalidCount = 0;
    final foods = <String, Food>{};
    for (final record in foodRecords.values) {
      final food = Food.fromRecord(record);
      if (food == null) {
        invalidCount++;
      } else {
        foods[food.id] = food;
      }
    }
    final entries = <FoodEntry>[];
    for (final record in entryRecords.values) {
      final entry = FoodEntry.fromRecord(record);
      if (entry == null) {
        invalidCount++;
      } else {
        entries.add(entry);
      }
    }
    return FoodDiary(
      foods: foods,
      entries: entries,
      invalidCount: invalidCount,
    );
  }

  /// Every food by id, including deleted ones.
  final Map<String, Food> foods;

  /// Every entry, including deleted ones, in the order they were made.
  final List<FoodEntry> entries;

  /// How many foods or entries were skipped because their data was not
  /// valid. Shown to the user, so nothing is hidden.
  final int invalidCount;

  /// The entries on [date] (`YYYY-MM-DD`) that are not deleted, in the
  /// order they were made.
  List<FoodEntry> entriesOn(String date) {
    return entries
        .where((entry) => entry.date == date && !entry.isDeleted)
        .toList();
  }

  /// The total nutrients eaten on [date].
  Nutrients totalOn(String date) {
    var total = Nutrients.none;
    for (final entry in entriesOn(date)) {
      total = total.plus(entry.nutrients);
    }
    return total;
  }

  /// The foods that are not deleted, most recently used first, then the
  /// rest in alphabetical order.
  List<Food> foodsByRecentUse() {
    final lastUse = <String, int>{};
    for (var index = 0; index < entries.length; index++) {
      final foodId = entries[index].foodId;
      if (foodId != null && !entries[index].isDeleted) {
        lastUse[foodId] = index;
      }
    }
    final activeFoods = foods.values.where((food) => !food.isDeleted).toList();
    activeFoods.sort((first, second) {
      final firstUse = lastUse[first.id] ?? -1;
      final secondUse = lastUse[second.id] ?? -1;
      if (firstUse != secondUse) {
        return secondUse.compareTo(firstUse);
      }
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return activeFoods;
  }
}
