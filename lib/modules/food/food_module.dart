// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../body/body_log.dart';
import 'daily_references.dart';
import 'screens/nutrient_bars.dart';
import '../body/screens/body_screen.dart';
import 'nutrients.dart';
import 'food_diary.dart';
import 'food_entry.dart';
import 'screens/food_diary_screen.dart';
import 'food_demo.dart';
import '../../core/number_input.dart';
import '../../core/units.dart';

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

  /// The energy eaten on [day] ("so far" today, or "of" the limit), with
  /// protein, carbs and fat as the mark, each against its daily amount;
  /// then how much is left (or when the last meal was, without a
  /// limit), and the daily average over the week before.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final diary = FoodDiary.of(appState);
    final date = formatDate(day);
    final entries = diary.entriesOn(date);
    final average = _averageEnergy(diary, day);
    final averageRow = average == null
        ? null
        : TileRow('Avg (7 days)', formatEnergy(average));
    if (entries.isEmpty) {
      return HomeTile(
        value: HomeTile.unknownValue,
        note: 'Nothing logged yet',
        rows: [if (averageRow != null) averageRow],
      );
    }
    final values = diary.totalOn(date).values;
    final body = BodyLog.of(appState);
    final references = dailyReferencesOn(body, date);
    final target = body.energyTargetOn(date);
    final energy = values[energyKey] ?? 0;
    const names = {
      'proteins_g': 'Protein',
      'carbohydrates_g': 'Carbs',
      'fat_g': 'Fat',
    };
    final hasMacros = names.keys.any(values.containsKey);
    final isToday = day == currentDay(now);
    // With a limit, how much is left matters more than the last meal
    // (which the Food page shows). Over the limit is in red.
    final TileRow? firstRow;
    if (target == null) {
      firstRow = _lastMealRow(latestTimedEntry(entries), day, now, isToday);
    } else if (energy <= target) {
      firstRow = TileRow(
        isToday ? 'Left today' : 'Under the limit',
        formatEnergy(target - energy),
      );
    } else {
      firstRow = TileRow(
        'Over the limit',
        formatEnergy(energy - target),
        isWarning: true,
      );
    }
    return HomeTile(
      value: formatEnergy(energy),
      // Against the limit when there is one; otherwise "so far": today is
      // not over, which is why it is usually below the average.
      valueNote: target != null
          ? 'of ${target.round()}'
          : isToday
          ? 'so far'
          : null,
      // Protein, carbs and fat, each with a bar of its daily amount.
      // Only quick entries have none; then no mark.
      mark: hasMacros
          ? NutrientBars(
              amounts: [
                for (final name in names.entries)
                  NutrientAmount(
                    name.key,
                    name.value,
                    values[name.key],
                    references[name.key],
                  ),
              ],
            )
          : null,
      rows: [
        if (firstRow != null) firstRow,
        if (averageRow != null) averageRow,
      ],
    );
  }

  /// The energy eaten on each of the seven days, in kilocalories.
  @override
  List<WeekRow> weekRows(AppState appState, DateTime day) {
    final diary = FoodDiary.of(appState);
    // Nothing ever logged: no row yet, as for the other modules.
    if (diary.entries.isEmpty) {
      return const [];
    }
    final cells = [
      for (final column in weekEndingOn(day))
        if (diary.entriesOn(formatDate(column)).isEmpty)
          null
        else
          '${diary.totalOn(formatDate(column)).energyKcal.round()}',
    ];
    return [
      WeekRow(
        label: 'Food (kcal)',
        cells: cells,
        description: 'Energy eaten each day, in kilocalories',
      ),
    ];
  }

  /// Days with any food logged.
  @override
  Set<String> datesLogged(AppState appState) => {
    for (final entry in FoodDiary.of(appState).entries)
      if (!entry.isDeleted) entry.date,
  };

  /// Body details and the daily calorie limit: set there, and also
  /// reached from the Food page.
  @override
  Widget? buildSettingsCard(AppState appState) =>
      BodySettingsCard(appState: appState);

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);

  /// Energy eaten, on days with food logged, and weight, on days
  /// weighed (the body details live with Food).
  @override
  List<TrendMeasure> trendMeasures(AppState appState) {
    final diary = FoodDiary.of(appState);
    final body = BodyLog.of(appState);
    return [
      if (diary.entries.isNotEmpty)
        TrendMeasure(
          label: 'Food',
          valueOn: (date) => diary.entriesOn(date).isEmpty
              ? null
              : diary.totalOn(date).energyKcal,
          format: (kcal) => '${formatThousands(kcal.round())} kcal',
        ),
      if (body.weights.any((weight) => !weight.isDeleted))
        TrendMeasure(
          label: 'Weight',
          valueOn: (date) => body.weightOn(date)?.weightKg,
          format: formatWeight,
          // Weight moves slowly: 1 % (about 0.7 kg) is already a change.
          steadyWithin: 0.01,
        ),
    ];
  }

  @override
  List<DemoEvent> demoEvents(DemoPlan plan) => foodDemoEvents(plan);
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

/// "Last meal" with "8 h ago" today, or "7:15 pm" on another day;
/// null without an entry that has a time.
TileRow? _lastMealRow(
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
    return TileRow('Last meal', showSavedTime(time));
  }
  return TileRow('Last meal', formatTimeAgo(elapsed));
}
