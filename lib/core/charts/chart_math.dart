// SPDX-License-Identifier: GPL-3.0-or-later

/// The arithmetic behind the charts: the running mean, the summary
/// numbers, and where the axes put their labels.
///
/// Everything here is plain, textbook arithmetic, so anyone can check a
/// chart by hand or in Python:
///
/// * the **running mean** on a day is the mean of the values logged in
///   the window of days ending that day (7 days, or 28 on long periods);
/// * the **mean** and **standard deviation** are the usual sample ones
///   (dividing by n − 1);
/// * the **change per week** is the slope of the least-squares straight
///   line through the values (value against day), times seven.
library;

import 'dart:math' as math;

import '../dates.dart';
import '../number_input.dart';
import 'chart_data.dart';

/// The values of [values] from [first] to [last] (both included),
/// oldest first.
List<DayValue> valuesBetween(
  List<DayValue> values,
  DateTime first,
  DateTime last,
) {
  final inside = [
    for (final value in values)
      if (!value.date.isBefore(first) && !value.date.isAfter(last)) value,
  ];
  inside.sort((a, b) => a.date.compareTo(b.date));
  return inside;
}

/// The spans of [ranges] from [first] to [last] (both included).
List<DayRange> rangesBetween(
  List<DayRange> ranges,
  DateTime first,
  DateTime last,
) => [
  for (final range in ranges)
    if (!range.date.isBefore(first) && !range.date.isAfter(last)) range,
];

/// How many days the running mean covers on a chart spanning [spanDays]
/// days: a week, or four weeks once a chart covers more than four
/// months, where a week's mean would still be too jumpy to show the
/// trend.
int meanWindowFor(int spanDays) => spanDays > 120 ? 28 : 7;

/// The running mean of [sortedValues] (oldest first) over [windowDays]
/// days: on each day with a value, the mean of the values in the
/// [windowDays] days ending that day.
///
/// It is worked out only on days with a value, so that with weigh-ins
/// every few days the line goes smoothly from one to the next, instead
/// of stepping each time an old value leaves the window.
///
/// Returned as pieces of line. Where two values are [windowDays] days
/// or more apart, the line stops, so the chart never draws a trend
/// across a gap nobody logged.
List<List<DayValue>> runningMean(List<DayValue> sortedValues, int windowDays) {
  final pieces = <List<DayValue>>[];
  var piece = <DayValue>[];
  // The window holds the values from index `start` to `index`. `start`
  // only moves forward, so this takes one pass.
  var start = 0;
  var sum = 0.0;
  for (var index = 0; index < sortedValues.length; index++) {
    final value = sortedValues[index];
    sum += value.value;
    while (daysBetween(sortedValues[start].date, value.date) >= windowDays) {
      sum -= sortedValues[start].value;
      start++;
    }
    final isAfterGap =
        index > 0 &&
        daysBetween(sortedValues[index - 1].date, value.date) >= windowDays;
    if (isAfterGap && piece.isNotEmpty) {
      pieces.add(piece);
      piece = <DayValue>[];
    }
    piece.add(DayValue(value.date, sum / (index - start + 1)));
  }
  if (piece.isNotEmpty) {
    pieces.add(piece);
  }
  return pieces;
}

/// The summary numbers of a chart's values over the period shown.
class ChartSummary {
  /// Creates a summary.
  const ChartSummary({
    required this.count,
    this.mean,
    this.standardDeviation,
    this.changePerWeek,
  });

  /// How many values there are.
  final int count;

  /// Their mean, or null without any.
  final double? mean;

  /// Their sample standard deviation, or null with fewer than two.
  final double? standardDeviation;

  /// The slope of the least-squares line through them, per week, or null
  /// when there are too few to tell (fewer than [trendNeedsValues], or
  /// spread over less than [trendNeedsDays] days).
  final double? changePerWeek;
}

/// How many values a change per week needs.
const int trendNeedsValues = 3;

/// Over how many days (first to last value) a change per week needs, so
/// that two weigh-ins on following days are not read as a trend.
const int trendNeedsDays = 7;

/// Works out the summary of [values].
ChartSummary summarize(List<DayValue> values) {
  final count = values.length;
  if (count == 0) {
    return const ChartSummary(count: 0);
  }
  final mean =
      values.map((value) => value.value).reduce((a, b) => a + b) / count;
  double? standardDeviation;
  if (count >= 2) {
    var squares = 0.0;
    for (final value in values) {
      squares += (value.value - mean) * (value.value - mean);
    }
    standardDeviation = math.sqrt(squares / (count - 1));
  }
  return ChartSummary(
    count: count,
    mean: mean,
    standardDeviation: standardDeviation,
    changePerWeek: _slopePerWeek(values, mean),
  );
}

/// The least-squares slope of [values] (value against day number), times
/// seven; null when there are too few values or days.
double? _slopePerWeek(List<DayValue> values, double meanValue) {
  if (values.length < trendNeedsValues) {
    return null;
  }
  var first = values.first.date;
  var last = values.first.date;
  for (final value in values) {
    if (value.date.isBefore(first)) first = value.date;
    if (value.date.isAfter(last)) last = value.date;
  }
  if (daysBetween(first, last) < trendNeedsDays) {
    return null;
  }
  final days = [for (final value in values) daysBetween(first, value.date)];
  final meanDay = days.reduce((a, b) => a + b) / days.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (var index = 0; index < values.length; index++) {
    final dayOffset = days[index] - meanDay;
    covariance += dayOffset * (values[index].value - meanValue);
    variance += dayOffset * dayOffset;
  }
  return covariance / variance * 7;
}

/// A value axis: from [min] to [max], with a label every [step].
class AxisScale {
  /// Creates the scale.
  const AxisScale(this.min, this.max, this.step);

  /// The bottom of the axis.
  final double min;

  /// The top of the axis.
  final double max;

  /// The distance between labels.
  final double step;

  /// The values that get a label and a grid line, bottom first.
  List<double> get ticks => [
    // A little slack, so the top tick is not lost to rounding.
    for (var tick = min; tick <= max + step / 1000; tick += step) tick,
  ];
}

/// A value axis covering [low] to [high] with round numbers at its ends
/// and about [targetTicks] steps between them, as a person would draw it
/// on graph paper.
///
/// The step is 1, 2, 2.5 or 5 times a power of ten, or, if [steps] is
/// given, the smallest of [steps] that is large enough (for hours:
/// 1, 2, 3, 6). [fixedMin] and [fixedMax] pin an end, such as 0 and 100
/// for a percentage. [smallestStep] keeps the step from getting smaller,
/// such as 1 for counts, which have no half reps.
AxisScale niceScale(
  double low,
  double high, {
  int targetTicks = 4,
  List<double>? steps,
  double? fixedMin,
  double? fixedMax,
  double? smallestStep,
}) {
  var bottom = fixedMin ?? low;
  var top = fixedMax ?? high;
  if (top <= bottom) {
    // A single value, or all values the same: show a little around it.
    final pad = bottom == 0 ? 1.0 : bottom.abs() * 0.05;
    bottom = fixedMin ?? bottom - pad;
    top = fixedMax ?? top + pad;
  }
  final step = math.max(
    _niceStep((top - bottom) / targetTicks, steps),
    smallestStep ?? 0,
  );
  final min = fixedMin ?? (bottom / step).floorToDouble() * step;
  var max = fixedMax ?? (top / step).ceilToDouble() * step;
  if (max <= min) {
    max = min + step;
  }
  return AxisScale(min, max, step);
}

/// The smallest round step at least [rough].
double _niceStep(double rough, List<double>? steps) {
  if (steps != null && steps.isNotEmpty) {
    for (final step in steps) {
      if (step >= rough) {
        return step;
      }
    }
    // Larger than every step given: whole multiples of the largest.
    final largest = steps.last;
    return (rough / largest).ceilToDouble() * largest;
  }
  final power = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  for (final multiple in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (multiple * power >= rough * 0.999) {
      return multiple * power;
    }
  }
  return 10 * power;
}

/// A value axis label for [value] on an axis stepping by [step]: as many
/// decimals as the step needs, thousands with commas (`1,500`), and
/// thousands as `k` once the step is 2,000 or more (`8k`), so the labels
/// stay narrow.
String formatTickNumber(double value, double step) {
  // Tiny leftovers of adding steps (0.30000000000000004) are not shown.
  final rounded = (value / step).round() * step;
  if (rounded.abs() < step / 1000) {
    return '0';
  }
  final sign = rounded < 0 ? '−' : '';
  final size = rounded.abs();
  // From steps of 2,000 on, thousands as `k`: `4k` is easier to take
  // in than `4,000` beside the plot. Smaller steps (kcal) keep every
  // digit.
  if (step >= 2000) {
    return '$sign${formatAmount(size / 1000)}k';
  }
  if (step >= 1) {
    return '$sign${formatThousands(size.round())}';
  }
  final decimals = step >= 0.1 ? 1 : 2;
  return '$sign${size.toStringAsFixed(decimals)}';
}

/// A label on the date axis.
class DateTick {
  /// Creates the label [label] at [date].
  const DateTick(this.date, this.label);

  /// Where the label goes.
  final DateTime date;

  /// What it says, such as `16 Nov`, `Oct` or `2027`.
  final String label;
}

/// The date axis labels from [first] to [last], spaced to suit the span:
///
/// * up to about six weeks: each Monday (`16 Nov`);
/// * up to about seven months: the first of each month (`Oct`);
/// * up to about two years: every second or third month;
/// * longer: each new year (`2027`).
///
/// A January shows its year instead of `Jan`, so it is always clear which
/// year the months belong to.
List<DateTick> dateTicks(DateTime first, DateTime last) {
  final span = daysBetween(first, last);
  if (span <= 45) {
    return [
      for (var day = first; !day.isAfter(last); day = addDays(day, 1))
        if (day.weekday == DateTime.monday)
          DateTick(day, '${day.day} ${shortMonthName(day.month)}'),
    ];
  }
  if (span <= 800) {
    final monthsApart = span <= 210 ? 1 : (span <= 400 ? 2 : 3);
    return [
      for (
        var month = DateTime(first.year, first.month + 1);
        !month.isAfter(last);
        month = DateTime(month.year, month.month + 1)
      )
        // Counted from January, so the same months are labeled each year.
        if ((month.month - 1) % monthsApart == 0)
          DateTick(month, _monthLabel(month)),
    ];
  }
  final years = last.year - first.year;
  final yearsApart = years <= 6 ? 1 : (years / 6).ceil();
  return [
    for (var year = first.year + 1; year <= last.year; year++)
      if (year % yearsApart == 0) DateTick(DateTime(year), '$year'),
  ];
}

/// `Oct`, or the year for January.
String _monthLabel(DateTime month) =>
    month.month == 1 ? '${month.year}' : shortMonthName(month.month);
