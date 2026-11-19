// SPDX-License-Identifier: GPL-3.0-or-later

/// A day's step count.
library;

import '../../core/dates.dart';
import '../../core/events/things.dart';

/// The steps walked on one day, typed in from a watch or phone. Created
/// by `steps_recorded`; see "Module: exercise" in `docs/data-format.md`.
class StepCount {
  /// Creates a step count.
  const StepCount({
    required this.id,
    required this.date,
    required this.steps,
    required this.isDeleted,
    required this.loggedAtUtc,
  });

  /// Reads a step count from its collected events. Returns null if the
  /// data is not valid.
  static StepCount? fromRecord(ThingRecord record) {
    final date = record.fields['date'];
    final steps = record.fields['steps'];
    if (date is! String || !isValidDate(date)) {
      return null;
    }
    if (steps is! int || steps < 0) {
      return null;
    }
    return StepCount(
      id: record.id,
      date: date,
      steps: steps,
      isDeleted: record.isDeleted,
      loggedAtUtc: record.createdAtUtc,
    );
  }

  /// The count's id: the id of the event that created it.
  final String id;

  /// The day the steps were walked, `YYYY-MM-DD`.
  final String date;

  /// How many steps.
  final int steps;

  /// Whether the count was deleted.
  final bool isDeleted;

  /// When it was first logged, in UTC.
  final DateTime loggedAtUtc;
}
