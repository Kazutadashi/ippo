// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import 'food_diary.dart';
import 'food_entry.dart';
import 'screens/food_diary_screen.dart';

/// The food module, as seen by the core app.
class FoodModule implements IppoModule {
  /// Creates the module.
  const FoodModule();

  @override
  String get moduleName => foodModuleName;

  @override
  String get title => 'Food';

  @override
  IconData get icon => Icons.restaurant;

  /// Two tiles: energy eaten today, and the last meal.
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final diary = FoodDiary.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(now);
    final entries = diary.entriesOn(today);
    final total = diary.totalOn(today);
    final lastMeal = _latestTimedEntry(entries);
    return [
      TodayFact(
        icon: Icons.local_fire_department,
        label: 'Energy',
        value: entries.isEmpty
            ? TodayFact.unknownValue
            : '${formatAmount(total.energyKcal)} kcal',
        detail: entries.isEmpty
            ? 'Nothing eaten logged yet'
            : _describeMacronutrients(total.values, entries.length),
      ),
      _lastMealFact(lastMeal, now),
    ];
  }

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);
}

/// The "Last meal" tile: how long ago the latest entry with a known time
/// was eaten.
TodayFact _lastMealFact(FoodEntry? lastMeal, DateTime now) {
  final time = lastMeal?.time;
  if (lastMeal == null || time == null) {
    return const TodayFact(
      icon: Icons.schedule,
      label: 'Last meal',
      value: TodayFact.unknownValue,
      detail: 'Not logged yet',
    );
  }
  final eatenAt = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(time.substring(0, 2)),
    int.parse(time.substring(3, 5)),
  );
  final elapsed = now.difference(eatenAt);
  return TodayFact(
    icon: Icons.schedule,
    label: 'Last meal',
    value: elapsed.isNegative ? time : formatTimeAgo(elapsed),
    detail: 'at $time · ${lastMeal.name}',
  );
}

/// The entry with the latest known time, or null if none has a time.
FoodEntry? _latestTimedEntry(List<FoodEntry> entries) {
  FoodEntry? latest;
  for (final entry in entries) {
    final time = entry.time;
    if (time == null) {
      continue;
    }
    // "HH:MM" texts sort the same way as the times they stand for.
    if (latest == null || time.compareTo(latest.time!) >= 0) {
      latest = entry;
    }
  }
  return latest;
}

/// Describes protein, carbohydrates and fat, for example
/// `Protein 56 g · Carbs 120 g · Fat 30 g`. If none are known, says how
/// many entries there are instead.
String _describeMacronutrients(Map<String, double> values, int entryCount) {
  const names = {
    'proteins_g': 'Protein',
    'carbohydrates_g': 'Carbs',
    'fat_g': 'Fat',
  };
  final parts = [
    for (final name in names.entries)
      if (values.containsKey(name.key))
        '${name.value} ${formatAmount(values[name.key]!)} g',
  ];
  if (parts.isEmpty) {
    return entryCount == 1 ? '1 entry' : '$entryCount entries';
  }
  return parts.join(' · ');
}
