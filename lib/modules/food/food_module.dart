// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module: a food diary and calorie tracker.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import 'food_diary.dart';
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

  /// For example: Eaten 1240 kcal · Protein 56 g · Last ate 3 h ago.
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final diary = FoodDiary.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(now);
    final entries = diary.entriesOn(today);
    if (entries.isEmpty) {
      return [];
    }
    final total = diary.totalOn(today);
    final protein = total.values['proteins_g'];
    final facts = [
      TodayFact('Eaten', '${formatAmount(total.energyKcal)} kcal'),
      if (protein != null) TodayFact('Protein', '${formatAmount(protein)} g'),
    ];
    final lastAte = _latestTime(entries.map((entry) => entry.time), now);
    if (lastAte != null && !now.isBefore(lastAte)) {
      facts.add(TodayFact('Last ate', formatTimeAgo(now.difference(lastAte))));
    }
    return facts;
  }

  @override
  Widget buildScreen(AppState appState) => FoodDiaryScreen(appState: appState);
}

/// The latest of [times] (`HH:MM`, or null when not known) on the day of
/// [now], as a moment. Returns null if no time is known.
DateTime? _latestTime(Iterable<String?> times, DateTime now) {
  DateTime? latest;
  for (final time in times) {
    if (time == null) {
      continue;
    }
    final moment = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(time.substring(0, 2)),
      int.parse(time.substring(3, 5)),
    );
    if (latest == null || moment.isAfter(latest)) {
      latest = moment;
    }
  }
  return latest;
}
