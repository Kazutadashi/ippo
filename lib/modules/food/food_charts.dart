// SPDX-License-Identifier: GPL-3.0-or-later

/// The Food tab's charts: weight, energy eaten against the calorie limit,
/// and protein.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import '../../core/units.dart';
import '../body/body_log.dart';
import 'food_diary.dart';

/// The field name of protein in the data (see "Nutrients" in
/// `docs/data-format.md`).
const String _proteinKey = 'proteins_g';

/// Weight, energy and protein over time, each only once something of it
/// was logged.
List<ChartSpec> foodCharts(AppState appState) {
  final diary = FoodDiary.of(appState);
  final body = BodyLog.of(appState);
  final foodDates = {
    for (final entry in diary.entries)
      if (!entry.isDeleted) entry.date,
  };
  final weightDates = {
    for (final weight in body.weights)
      if (!weight.isDeleted) weight.date,
  };
  return [
    if (weightDates.isNotEmpty) _weightChart(body, weightDates),
    if (foodDates.isNotEmpty) _energyChart(diary, body, foodDates),
    if (foodDates.isNotEmpty) _proteinChart(diary, foodDates),
  ];
}

/// Weight in the unit chosen in Settings. The axis zooms in on the
/// weights, as a change of a kilogram is what matters.
ChartSpec _weightChart(BodyLog body, Set<String> dates) {
  String inUnit(double value) => '${formatAmount(value)} $weightUnit';
  return ChartSpec(
    title: 'Weight',
    unit: weightUnit,
    values: dailyValues(dates, (date) {
      final weight = body.weightOn(date)?.weightKg;
      return weight == null ? null : weightInShownUnit(weight);
    }),
    format: inUnit,
    valueLabel: 'Each weigh-in',
    countLabel: 'Weigh-ins',
    icon: Icons.monitor_weight_outlined,
  );
}

/// Energy eaten each day logged, with the calorie limit that applied.
ChartSpec _energyChart(FoodDiary diary, BodyLog body, Set<String> dates) {
  final firstDay = parseDate(
    dates.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
  );
  return ChartSpec(
    title: 'Energy',
    unit: 'kcal',
    values: dailyValues(dates, (date) => diary.totalOn(date).energyKcal),
    format: (kcal) => '${formatThousands(kcal.round())} kcal',
    mark: ChartMark.bars,
    startsAtZero: true,
    isRunningTotal: true,
    limit: firstDay == null ? const [] : _limitFrom(body, firstDay),
    limitLabel: 'Calorie limit',
  );
}

/// The calorie limit on each day from [firstDay] to today, where one was
/// set.
List<DayValue> _limitFrom(BodyLog body, DateTime firstDay) {
  final last = today();
  return [
    for (var day = firstDay; !day.isAfter(last); day = addDays(day, 1))
      if (body.energyTargetOn(formatDate(day)) case final kcal?)
        DayValue(day, kcal),
  ];
}

/// Protein eaten each day logged, on days when any food said how much.
ChartSpec _proteinChart(FoodDiary diary, Set<String> dates) {
  return ChartSpec(
    title: 'Protein',
    unit: 'g',
    values: dailyValues(
      dates,
      (date) => diary.totalOn(date).values[_proteinKey],
    ),
    format: (grams) => '${formatAmount(grams.roundToDouble())} g',
    mark: ChartMark.bars,
    startsAtZero: true,
    isRunningTotal: true,
  );
}
