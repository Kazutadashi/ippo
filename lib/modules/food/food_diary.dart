// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module's current state, worked out from the event log.
library;

import '../../core/app_state.dart';
import '../../core/dates.dart';
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
    this.dayMarks = const {},
  });

  /// The current state for [appState], worked out once per change of
  /// the data and shared by every screen (see `AppState.derived`).
  static FoodDiary of(AppState appState) => appState.derived(
    'food_diary',
    FoodDiary.fromEvents,
    module: foodModuleName,
  );

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
      dayMarks: _dayMarksFrom(events),
    );
  }

  /// Every food by id, including deleted ones.
  final Map<String, Food> foods;

  /// Every entry, including deleted ones, in the order they were made.
  final List<FoodEntry> entries;

  /// The user's mark for each day ever marked (`YYYY-MM-DD`): true if
  /// everything eaten that day is logged, false if not. See
  /// `diary_day_marked` in `docs/data-format.md`.
  final Map<String, bool> dayMarks;

  /// Whether [date] is marked complete (true), marked not complete
  /// (false), or was never marked (null).
  bool? markOn(String date) => dayMarks[date];

  /// How many foods or entries were skipped because their data was not
  /// valid. Shown to the user, so nothing is hidden.
  final int invalidCount;

  /// The food in the list called [name], ignoring case and spaces at the
  /// ends, or null if there is none. Deleted foods do not count.
  Food? foodNamed(String name) {
    final wanted = name.trim().toLowerCase();
    for (final food in foods.values) {
      if (!food.isDeleted && food.name.trim().toLowerCase() == wanted) {
        return food;
      }
    }
    return null;
  }

  /// The entries on [date] (`YYYY-MM-DD`) that are not deleted, in the
  /// order they were made.
  List<FoodEntry> entriesOn(String date) => _entriesByDay[date] ?? const [];

  /// The entries that are not deleted, by day, in the order they were
  /// made. Built once, the first time it is needed, so the screens that
  /// look at many days (Home's week, Lately) do not search every entry
  /// for each day.
  late final Map<String, List<FoodEntry>> _entriesByDay = () {
    final byDay = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      if (!entry.isDeleted) {
        byDay.putIfAbsent(entry.date, () => []).add(entry);
      }
    }
    // Read-only, as every caller gets the same list.
    return {
      for (final day in byDay.entries)
        day.key: List<FoodEntry>.unmodifiable(day.value),
    };
  }();

  /// The most recent entry of the food [foodId] that is not deleted, or
  /// null if it was never logged. Its amount is a good first guess for
  /// the next one: people tend to eat the same amount of a food.
  FoodEntry? lastEntryOf(String foodId) {
    for (final entry in entries.reversed) {
      if (entry.foodId == foodId && !entry.isDeleted) {
        return entry;
      }
    }
    return null;
  }

  /// The total nutrients eaten on [date].
  Nutrients totalOn(String date) {
    var total = Nutrients.none;
    for (final entry in entriesOn(date)) {
      // Each entry's salt and sodium in step first, so the day's totals
      // of both count every entry that gave either.
      total = total.plus(entry.nutrients.withSaltAndSodium());
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

/// The entry eaten last, by its time, or null if none has a time.
/// Times are compared as moments, so 01:05 (after midnight) comes after
/// 23:30 on the same day.
FoodEntry? latestTimedEntry(List<FoodEntry> entries) {
  FoodEntry? latest;
  DateTime? latestMoment;
  // Any fixed day works for comparing; only the order matters.
  final anyDay = DateTime(2000);
  for (final entry in entries) {
    final time = entry.time;
    final moment = time == null ? null : momentOnDay(anyDay, time);
    if (moment == null) {
      continue;
    }
    if (latestMoment == null || !moment.isBefore(latestMoment)) {
      latest = entry;
      latestMoment = moment;
    }
  }
  return latest;
}

/// The latest `diary_day_marked` of each day in [events] (oldest first,
/// so a later mark replaces an earlier one). Events that are not valid
/// are skipped.
Map<String, bool> _dayMarksFrom(List<Event> events) {
  final marks = <String, bool>{};
  for (final event in events) {
    if (event.module != foodModuleName || event.type != 'diary_day_marked') {
      continue;
    }
    final date = event.data['date'];
    final complete = event.data['complete'];
    if (date is String && isValidDate(date) && complete is bool) {
      marks[date] = complete;
    }
  }
  return marks;
}
