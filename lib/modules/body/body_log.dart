// SPDX-License-Identifier: GPL-3.0-or-later

/// Body measurements and the daily energy target, worked out from the
/// event log.
///
/// They follow `docs/data-format.md`, section "Module: body". The food
/// screens use them for the calorie limit and the reference amounts.
library;

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/events/event.dart';
import '../../core/events/things.dart';

/// The module's name in event files. Never change it.
const String bodyModuleName = 'body';

/// Sex, for the BMR formula, which differs between the two.
enum Sex {
  /// Female.
  female,

  /// Male.
  male;

  /// Reads a sex from its name in the data, or null.
  static Sex? fromName(Object? name) {
    for (final sex in Sex.values) {
      if (sex.name == name) {
        return sex;
      }
    }
    return null;
  }
}

/// One weighing. Created by `weight_recorded`.
class WeightEntry {
  /// Creates a weighing.
  const WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.isDeleted,
  });

  /// The weighing's id: the id of the event that created it.
  final String id;

  /// The day, `YYYY-MM-DD`.
  final String date;

  /// The weight in kilograms.
  final double weightKg;

  /// Whether it was deleted.
  final bool isDeleted;
}

/// A daily energy target, from [date] on. Recorded by
/// `energy_target_recorded`.
class EnergyTarget {
  /// Creates a target.
  const EnergyTarget({required this.date, required this.energyKcal});

  /// The first day it applies to, `YYYY-MM-DD`.
  final String date;

  /// The most kilocalories a day, or null for "no target" (a target that
  /// was removed).
  final double? energyKcal;
}

/// Whether a goal is a most or a least.
enum GoalKind {
  /// A most, such as fat or salt: going past it is going over.
  atMost('at_most'),

  /// A least, such as protein or fiber: going past it is fine.
  atLeast('at_least');

  const GoalKind(this.name);

  /// The name in the data.
  final String name;

  /// The kind called [name] in the data, or null if unknown.
  static GoalKind? fromName(Object? name) {
    for (final kind in values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }
}

/// The user's own daily goal for one nutrient, from [date] on, in place
/// of the reference amount. Recorded by `nutrient_target_recorded`.
class NutrientTarget {
  /// Creates a goal.
  const NutrientTarget({
    required this.date,
    required this.nutrient,
    required this.amount,
    required this.kind,
  });

  /// The first day it applies to, `YYYY-MM-DD`.
  final String date;

  /// The nutrient's field name, such as `fat_g`.
  final String nutrient;

  /// The amount a day, in the unit of [nutrient]; null when the goal
  /// was removed, so the reference amount applies again.
  final double? amount;

  /// Whether [amount] is a most or a least.
  final GoalKind kind;
}

/// Everything recorded about the body, with every change applied.
class BodyLog {
  /// Creates a log. Normal code uses [BodyLog.fromEvents].
  BodyLog({
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weights,
    required this.targets,
    required this.invalidCount,
    this.nutrientTargets = const [],
  });

  /// The current state for [appState], worked out once per change of
  /// the data and shared by every screen.
  static BodyLog of(AppState appState) =>
      appState.derived('body_log', BodyLog.fromEvents);

  /// Builds the log from the event log's events (oldest first).
  factory BodyLog.fromEvents(List<Event> events) {
    var invalidCount = 0;
    Sex? sex;
    int? birthYear;
    double? heightCm;
    final targets = <EnergyTarget>[];
    final nutrientTargets = <NutrientTarget>[];
    for (final event in events) {
      if (event.module != bodyModuleName) {
        continue;
      }
      final data = event.data;
      if (event.type == 'profile_recorded') {
        // Each field the event has replaces the one before.
        sex = Sex.fromName(data['sex']) ?? sex;
        final year = data['birth_year'];
        if (year is int && year > 1900) {
          birthYear = year;
        }
        final height = data['height_cm'];
        if (height is num && height > 0) {
          heightCm = height.toDouble();
        }
      } else if (event.type == 'energy_target_recorded') {
        final date = data['date'];
        final energy = data['energy_kcal'];
        if (date is! String || !isValidDate(date)) {
          invalidCount++;
          continue;
        }
        targets.add(
          EnergyTarget(
            date: date,
            energyKcal: energy is num && energy > 0 ? energy.toDouble() : null,
          ),
        );
      } else if (event.type == 'nutrient_target_recorded') {
        final date = data['date'];
        final nutrient = data['nutrient'];
        final amount = data['amount'];
        final kind = GoalKind.fromName(data['kind']);
        if (date is! String ||
            !isValidDate(date) ||
            nutrient is! String ||
            nutrient.isEmpty ||
            kind == null) {
          invalidCount++;
          continue;
        }
        nutrientTargets.add(
          NutrientTarget(
            date: date,
            nutrient: nutrient,
            amount: amount is num && amount > 0 ? amount.toDouble() : null,
            kind: kind,
          ),
        );
      }
    }

    final weights = <WeightEntry>[];
    final records = collectThings(
      events,
      module: bodyModuleName,
      createdType: 'weight_recorded',
      thingName: 'weight',
    ).values;
    for (final record in records) {
      final date = record.fields['date'];
      final weight = record.fields['weight_kg'];
      if (date is! String || !isValidDate(date) || weight is! num) {
        invalidCount++;
        continue;
      }
      weights.add(
        WeightEntry(
          id: record.id,
          date: date,
          weightKg: weight.toDouble(),
          isDeleted: record.isDeleted,
        ),
      );
    }
    weights.sort((first, second) => first.date.compareTo(second.date));

    return BodyLog(
      sex: sex,
      birthYear: birthYear,
      heightCm: heightCm,
      weights: weights,
      targets: targets,
      invalidCount: invalidCount,
      nutrientTargets: nutrientTargets,
    );
  }

  /// Sex, or null if not given.
  final Sex? sex;

  /// The year of birth, or null if not given.
  final int? birthYear;

  /// Height in centimeters, or null if not given.
  final double? heightCm;

  /// Every weighing, including deleted ones, by date.
  final List<WeightEntry> weights;

  /// Every energy target, in the order recorded.
  final List<EnergyTarget> targets;

  /// How many things were skipped because their data was not valid.
  final int invalidCount;

  /// The weighing on [date], or null.
  WeightEntry? weightOn(String date) {
    WeightEntry? found;
    for (final weight in weights) {
      if (weight.date == date && !weight.isDeleted) {
        found = weight;
      }
    }
    return found;
  }

  /// The latest weight on or before [date], in kilograms, or null.
  double? weightAsOf(String date) {
    double? found;
    for (final weight in weights) {
      if (!weight.isDeleted && weight.date.compareTo(date) <= 0) {
        found = weight.weightKg;
      }
    }
    return found;
  }

  /// The energy target that applies on [date]: of the targets starting
  /// on or before it, the one recorded last. Null for none.
  double? energyTargetOn(String date) {
    double? found;
    String? foundDate;
    for (final target in targets) {
      final applies = target.date.compareTo(date) <= 0;
      final isLater =
          foundDate == null || target.date.compareTo(foundDate) >= 0;
      if (applies && isLater) {
        found = target.energyKcal;
        foundDate = target.date;
      }
    }
    return found;
  }

  /// Every nutrient goal ever set, in the order recorded.
  final List<NutrientTarget> nutrientTargets;

  /// The user's goal for [nutrient] on [date]: of the goals for it
  /// starting on or before that day, the one with the latest date (of
  /// two with the same date, the one recorded last). Null if there is
  /// none, or it was removed: then the reference amount applies. So a
  /// new goal never changes past days.
  NutrientTarget? nutrientTargetOn(String nutrient, String date) {
    NutrientTarget? found;
    for (final target in nutrientTargets) {
      final applies =
          target.nutrient == nutrient && target.date.compareTo(date) <= 0;
      if (applies &&
          (found == null || target.date.compareTo(found.date) >= 0)) {
        found = target;
      }
    }
    return found?.amount == null ? null : found;
  }
}
