// SPDX-License-Identifier: GPL-3.0-or-later

/// Basal metabolic rate and daily energy needs.
library;

import 'body_log.dart';

/// The energy the body uses a day at complete rest, in kilocalories, by
/// the Mifflin-St Jeor equation (1990), the one most dietitians use:
///
///     10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) + s
///
/// where s is +5 for men and −161 for women. Null when anything needed
/// is not known.
double? basalMetabolicRate({
  required Sex? sex,
  required double? weightKg,
  required double? heightCm,
  required int? ageYears,
}) {
  if (sex == null || weightKg == null || heightCm == null || ageYears == null) {
    return null;
  }
  final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  return base + (sex == Sex.male ? 5 : -161);
}

/// How active a day is, with the usual factors that turn the BMR into
/// the energy used in a whole day.
enum ActivityLevel {
  /// Little or no exercise.
  sedentary('Little exercise', 1.2),

  /// Light exercise one to three days a week.
  light('Light, 1–3 days a week', 1.375),

  /// Moderate exercise three to five days a week.
  moderate('Moderate, 3–5 days a week', 1.55),

  /// Hard exercise six or seven days a week.
  active('Hard, 6–7 days a week', 1.725);

  const ActivityLevel(this.description, this.factor);

  /// What the level means, for the screen.
  final String description;

  /// The BMR times this is the energy used in a day.
  final double factor;
}
