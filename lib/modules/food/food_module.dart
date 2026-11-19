// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import 'nutrients.dart';
import 'food_diary.dart';
import 'food_entry.dart';
import 'screens/food_diary_screen.dart';

/// The food module, as seen by the core app.
class FoodModule extends IppoModule {
  /// Creates the module.
  const FoodModule();

  @override
  String get moduleName => foodModuleName;

  @override
  String get title => 'Food';

  @override
  IconData get icon => Icons.restaurant;

  @override
  Color get color => const Color(0xFFD69A2D); // warm amber

  /// Two tiles: energy eaten today, and the last meal.
  @override
  List<TodayFact> dayFacts(AppState appState, DateTime day, DateTime now) {
    final diary = FoodDiary.of(appState);
    final entries = diary.entriesOn(formatDate(day));
    final total = diary.totalOn(formatDate(day));
    return [
      if (entries.isEmpty)
        const TodayFact(
          label: 'Energy',
          value: TodayFact.unknownValue,
          note: 'Nothing logged yet',
        )
      else
        _energyFact(total.values, entries.length),
      _lastMealFact(_latestTimedEntry(entries), day, now),
    ];
  }

  @override
  TileDetail? weekSummary(AppState appState, DateTime day) {
    final diary = FoodDiary.of(appState);
    var total = 0.0;
    var loggedDays = 0;
    for (var back = 0; back < 7; back++) {
      final date = formatDate(addDays(day, -back));
      if (diary.entriesOn(date).isNotEmpty) {
        total += diary.totalOn(date).energyKcal;
        loggedDays++;
      }
    }
    if (loggedDays == 0) {
      return null;
    }
    // The average of the days with food logged: a day not logged is not
    // a day without food.
    return TileDetail(
      '${formatAmount(total / loggedDays)} kcal',
      label: 'Energy / day',
    );
  }

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);
}

/// The "Energy" tile: the day's energy, with protein, carbohydrates and
/// fat below it as small labelled columns.
TodayFact _energyFact(Map<String, double> values, int entryCount) {
  const names = {
    'proteins_g': 'Protein',
    'carbohydrates_g': 'Carbs',
    'fat_g': 'Fat',
  };
  final details = [
    for (final name in names.entries)
      if (values.containsKey(name.key))
        TileDetail('${formatAmount(values[name.key]!)} g', label: name.value),
  ];
  return TodayFact(
    label: 'Energy',
    value: '${formatAmount(values[energyKey] ?? 0)} kcal',
    details: details,
    // Without any of them (only quick entries), say how much was logged.
    note: details.isEmpty
        ? (entryCount == 1 ? '1 entry' : '$entryCount entries')
        : null,
  );
}

/// The "Last meal" tile: how long ago the latest entry with a known time
/// was eaten, then what it was and when. Looking back at an earlier day,
/// the value is simply the time.
TodayFact _lastMealFact(FoodEntry? lastMeal, DateTime day, DateTime now) {
  final time = lastMeal?.time;
  final eatenAt = time == null ? null : momentOnDay(day, time);
  if (lastMeal == null || time == null || eatenAt == null) {
    return const TodayFact(
      label: 'Last meal',
      value: TodayFact.unknownValue,
      note: 'Not logged yet',
    );
  }
  final elapsed = now.difference(eatenAt);
  final isToday = day == currentDay(now);
  return TodayFact(
    label: 'Last meal',
    value: !isToday || elapsed.isNegative
        ? showSavedTime(time)
        : formatTimeAgo(elapsed),
    details: [
      TileDetail(lastMeal.name),
      TileDetail('at ${showSavedTime(time)}'),
    ],
  );
}

/// The entry eaten last, by its time, or null if none has a time.
/// Times are compared as moments, so 01:05 (after midnight) comes after
/// 23:30 on the same day.
FoodEntry? _latestTimedEntry(List<FoodEntry> entries) {
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
