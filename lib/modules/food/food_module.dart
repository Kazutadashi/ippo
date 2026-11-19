// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
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

  /// The energy eaten on [day] ("so far" today), with protein, carbs
  /// and fat as the mark; then the last meal and the 7-day average.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final diary = FoodDiary.of(appState);
    final date = formatDate(day);
    final entries = diary.entriesOn(date);
    final average = _averageEnergy(diary, day);
    final averageLine = average == null
        ? null
        : '7-day avg ${formatEnergy(average)}';
    if (entries.isEmpty) {
      return HomeTile(
        value: HomeTile.unknownValue,
        lines: ['Nothing logged yet', if (averageLine != null) averageLine],
      );
    }
    final values = diary.totalOn(date).values;
    const names = {
      'proteins_g': 'Protein',
      'carbohydrates_g': 'Carbs',
      'fat_g': 'Fat',
    };
    final macros = [
      for (final name in names.entries)
        if (values.containsKey(name.key))
          TileDetail(formatGrams(values[name.key]!), label: name.value),
    ];
    final isToday = day == currentDay(now);
    final lastMealLine = _lastMealLine(
      latestTimedEntry(entries),
      day,
      now,
      isToday,
    );
    return HomeTile(
      value: formatEnergy(values[energyKey] ?? 0),
      // Today is not over: the total is so far, which is why it is
      // usually below the average.
      valueNote: isToday ? 'so far' : null,
      // Only quick entries have no macros; then no mark.
      mark: macros.isEmpty ? null : LabelledValues(details: macros),
      lines: [
        if (lastMealLine != null) lastMealLine,
        if (averageLine != null) averageLine,
      ],
    );
  }

  /// The energy eaten on each of the seven days, in kilocalories.
  @override
  WeekRow? weekRow(AppState appState, DateTime day) {
    final diary = FoodDiary.of(appState);
    // Nothing ever logged: no row yet, as for the other modules.
    if (diary.entries.isEmpty) {
      return null;
    }
    final cells = [
      for (final column in weekEndingOn(day))
        if (diary.entriesOn(formatDate(column)).isEmpty)
          null
        else
          '${diary.totalOn(formatDate(column)).energyKcal.round()}',
    ];
    return WeekRow(
      label: 'Food (kcal)',
      cells: cells,
      description: 'Energy eaten each day, in kilocalories',
    );
  }

  /// Days with any food logged.
  @override
  Set<String> datesLogged(AppState appState) => {
    for (final entry in FoodDiary.of(appState).entries)
      if (!entry.isDeleted) entry.date,
  };

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);
}

/// The average energy a day over the week before [day], counting only
/// days with food logged (a day not logged is not a day without food);
/// null without any.
double? _averageEnergy(FoodDiary diary, DateTime day) {
  var total = 0.0;
  var loggedDays = 0;
  for (final before in daysBefore(day)) {
    final date = formatDate(before);
    if (diary.entriesOn(date).isNotEmpty) {
      total += diary.totalOn(date).energyKcal;
      loggedDays++;
    }
  }
  return loggedDays == 0 ? null : total / loggedDays;
}

/// "Last meal 8 h ago" today, or "Last meal at 7:15 pm" on another day;
/// null without an entry that has a time.
String? _lastMealLine(
  FoodEntry? lastMeal,
  DateTime day,
  DateTime now,
  bool isToday,
) {
  final time = lastMeal?.time;
  final eatenAt = time == null ? null : momentOnDay(day, time);
  if (time == null || eatenAt == null) {
    return null;
  }
  final elapsed = now.difference(eatenAt);
  if (!isToday || elapsed.isNegative) {
    return 'Last meal at ${showSavedTime(time)}';
  }
  return 'Last meal ${formatTimeAgo(elapsed)}';
}
