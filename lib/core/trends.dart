// SPDX-License-Identifier: GPL-3.0-or-later

/// "Lately": how the last week compares with the weeks before it, for
/// each measure a module offers (see `IppoModule.trendMeasures`).
///
/// The comparison is deliberately simple, so anyone can check it by
/// hand: the average of the last 7 days against the average of the 28
/// days before them. Only days with something logged count, so a missing
/// day never looks like a zero.
library;

import 'dates.dart';

/// How many days "this week" covers, ending on the day shown.
const int trendRecentDays = 7;

/// How many days before this week make up "your usual".
const int trendUsualDays = 28;

/// How many days with a value "your usual" needs, so a couple of early
/// days are not taken for a habit.
const int _usualNeeds = 7;

/// A change smaller than this share of the usual (5 %) counts as
/// steady: day-to-day noise, not a change.
const double _steadyShare = 0.05;

/// One measure on the Lately card, such as steps or hours slept.
class TrendMeasure {
  /// Creates a measure.
  const TrendMeasure({
    required this.label,
    required this.valueOn,
    required this.format,
    this.isPerWeek = false,
  });

  /// Its name on the card, such as `Steps`.
  final String label;

  /// Its value on a day (`YYYY-MM-DD`), or null if nothing was logged
  /// that day.
  final double? Function(String date) valueOn;

  /// Writes a value (an average) for the card, such as `7,800`.
  final String Function(double value) format;

  /// True for a count per week, such as workout days: the daily values
  /// (1 or 0) are shown as a weekly total instead of a daily average.
  final bool isPerWeek;
}

/// Which way a measure has moved.
enum TrendDirection {
  /// Higher this week than usual.
  up,

  /// Lower this week than usual.
  down,

  /// About the same (within 5 %).
  steady,

  /// Not known: too little data this week or before it.
  unknown,
}

/// A measure's value this week and usually, worked out by [trendOf].
class Trend {
  /// Creates a trend.
  const Trend({
    required this.measure,
    required this.recent,
    required this.usual,
  });

  /// The measure this is for.
  final TrendMeasure measure;

  /// This week's average (or weekly total), or null if nothing logged.
  final double? recent;

  /// The usual average (or weekly total) over the 28 days before, or
  /// null if there are too few days to tell.
  final double? usual;

  /// Which way this week differs from usual.
  TrendDirection get direction {
    final recent = this.recent;
    final usual = this.usual;
    if (recent == null || usual == null) {
      return TrendDirection.unknown;
    }
    if (usual == 0) {
      // Nothing usually (no workouts, say): any at all is a rise.
      return recent > 0 ? TrendDirection.up : TrendDirection.steady;
    }
    // The change as a share of the usual, so 5 % means the same for
    // steps as for hours.
    final change = (recent - usual) / usual.abs();
    if (change.abs() <= _steadyShare) {
      return TrendDirection.steady;
    }
    return change > 0 ? TrendDirection.up : TrendDirection.down;
  }
}

/// Works out [measure] for the week ending on [day] against the 28 days
/// before it.
Trend trendOf(TrendMeasure measure, DateTime day) {
  final recent = _valuesOver(measure, day, 0, trendRecentDays);
  final usual = _valuesOver(measure, day, trendRecentDays, trendUsualDays);
  return Trend(
    measure: measure,
    recent: recent.isEmpty ? null : _summary(measure, recent),
    usual: usual.length < _usualNeeds ? null : _summary(measure, usual),
  );
}

/// The values of [measure] on [count] days, starting [skip] days before
/// [day] and going back. Days without a value are left out.
List<double> _valuesOver(
  TrendMeasure measure,
  DateTime day,
  int skip,
  int count,
) {
  final values = <double>[];
  for (var back = skip; back < skip + count; back++) {
    final value = measure.valueOn(formatDate(addDays(day, -back)));
    if (value != null) {
      values.add(value);
    }
  }
  return values;
}

/// The average of [values], or for a per-week measure the average times
/// seven: a weekly total.
double _summary(TrendMeasure measure, List<double> values) {
  final average = values.reduce((a, b) => a + b) / values.length;
  return measure.isPerWeek ? average * 7 : average;
}
