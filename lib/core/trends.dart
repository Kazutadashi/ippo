// SPDX-License-Identifier: GPL-3.0-or-later

/// "Lately": how the last 7 days compare with the weeks before them, for
/// each measure a module offers (see `IppoModule.trendMeasures`).
///
/// The comparison is deliberately simple, so anyone can check it by
/// hand: the average of the last 7 days against the average of the 28
/// days before them. Only days with something logged count, so a missing
/// day never looks like a zero.
///
/// The day shown (usually today) is left out: it is not over yet, and
/// half a day of food or steps would pull every average down. So "the
/// last 7 days" are the 7 days before it, the same days as the tiles'
/// "Avg (7 days)", and the numbers match.
library;

import 'dates.dart';

/// How many days "the last week" covers, ending the day before the one
/// shown.
const int trendRecentDays = 7;

/// How many days before the last week make up "your usual".
const int trendUsualDays = 28;

/// How many days with a value "your usual" needs, so a couple of early
/// days are not taken for a habit.
const int _usualNeeds = 7;

/// One measure on the Lately card, such as steps or hours slept.
class TrendMeasure {
  /// Creates a measure.
  const TrendMeasure({
    required this.label,
    required this.valueOn,
    required this.format,
    this.isPerWeek = false,
    this.steadyWithin = 0.05,
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

  /// A change smaller than this share of the usual counts as steady:
  /// day-to-day noise, not a change. 5 % by default; less for measures
  /// that move slowly, such as weight, where 1 % is already a lot.
  final double steadyWithin;
}

/// Which way a measure has moved.
enum TrendDirection {
  /// Higher in the last 7 days than usual.
  up,

  /// Lower in the last 7 days than usual.
  down,

  /// About the same (within 5 %).
  steady,

  /// Not known: too little data in the last 7 days or before them.
  unknown,
}

/// A measure's value in the last 7 days and usually, worked out by
/// [trendOf].
class Trend {
  /// Creates a trend.
  const Trend({
    required this.measure,
    required this.recent,
    required this.usual,
  });

  /// The measure this is for.
  final TrendMeasure measure;

  /// The last 7 days' average (or weekly total), or null if nothing
  /// logged.
  final double? recent;

  /// The usual average (or weekly total) over the 28 days before, or
  /// null if there are too few days to tell.
  final double? usual;

  /// Which way the last 7 days differ from usual.
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
    if (change.abs() <= measure.steadyWithin) {
      return TrendDirection.steady;
    }
    return change > 0 ? TrendDirection.up : TrendDirection.down;
  }
}

/// Works out [measure] for the 7 days before [day] against the 28 days
/// before those.
Trend trendOf(TrendMeasure measure, DateTime day) {
  // Day 0 is the day shown, which is not over yet: start the day before.
  final recent = _valuesOver(measure, day, 1, trendRecentDays);
  final usual = _valuesOver(measure, day, 1 + trendRecentDays, trendUsualDays);
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
