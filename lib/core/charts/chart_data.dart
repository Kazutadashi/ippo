// SPDX-License-Identifier: GPL-3.0-or-later

/// What a chart shows: the types a module uses to describe its charts
/// (see `IppoModule.charts`).
///
/// A module only says *what* to plot: one value per day, and a few
/// optional extras such as a limit or a recommended band. The core draws
/// every chart the same way (see `chart_card.dart`), works out the
/// running mean and the summary numbers (see `chart_math.dart`), and
/// handles the period shown. So a new chart is a few lines in its
/// module, and every chart reads the same.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';

/// One value on one day, such as 72.4 kg on 18 Nov.
class DayValue {
  /// Creates the value [value] on [date] (a day, with no time).
  const DayValue(this.date, this.value);

  /// The day the value is about.
  final DateTime date;

  /// The value, in the chart's unit.
  final double value;
}

/// A span on one day, from [low] to [high], such as a night's sleep from
/// bedtime to waking up.
class DayRange {
  /// Creates the span from [low] to [high] on [date].
  const DayRange(this.date, this.low, this.high);

  /// The day the span is about.
  final DateTime date;

  /// Where the span starts, in the chart's unit.
  final double low;

  /// Where the span ends, in the chart's unit.
  final double high;
}

/// How a chart draws its daily values.
enum ChartMark {
  /// A small dot per day: for measurements, such as weight.
  dots,

  /// A thin bar up from zero per day: for amounts, such as steps.
  bars,

  /// Nothing: the values are only used for the mean line and the
  /// summary, while [ChartSpec.ranges] are drawn.
  none,
}

/// A band of values recommended by a published source, such as 7 to 9
/// hours of sleep. Drawn as a faint stripe behind the data.
class ReferenceBand {
  /// Creates the band from [low] to [high].
  const ReferenceBand({
    required this.low,
    required this.high,
    required this.label,
  });

  /// Its lower edge, in the chart's unit.
  final double low;

  /// Its upper edge, in the chart's unit.
  final double high;

  /// Its name in the legend, such as `7–9 h advised`.
  final String label;
}

/// One chart: one measure over time, such as weight.
///
/// The core shows it as a card: the title with its unit, four summary
/// numbers for the period shown (mean, standard deviation, change per
/// week, number of days), the plot, and a legend. Tapping the plot reads
/// out one day.
class ChartSpec {
  /// Creates a chart. [values] may be in any order; each day should
  /// appear once.
  const ChartSpec({
    required this.title,
    required this.values,
    required this.format,
    this.unit,
    this.formatChange,
    this.formatTick,
    this.mark = ChartMark.dots,
    this.valueLabel = 'Each day',
    this.countLabel = 'Days',
    this.ranges = const [],
    this.rangeLabel,
    this.limit = const [],
    this.limitLabel = 'Limit',
    this.reference,
    this.note,
    this.startsAtZero = false,
    this.fixedMin,
    this.fixedMax,
    this.tickSteps,
    this.isWholeNumber = false,
    this.isRunningTotal = false,
    this.icon,
  });

  /// The chart's name, such as `Weight` or `Push-up`.
  final String title;

  /// The unit of every value, shown after the title, such as `kg`; null
  /// when the values are not amounts (clock times).
  final String? unit;

  /// The measure, one value per day logged. Days without a value are
  /// left out, never given zero, so a gap never looks like a low day.
  final List<DayValue> values;

  /// Writes a value for the summary and the read-out, such as `72.4 kg`.
  final String Function(double value) format;

  /// Writes a difference between values (always positive: the standard
  /// deviation, or the change per week without its sign), such as
  /// `0.4 kg` or `35 min`. Null to use [format], which suits most
  /// measures; clock times need their own, since a spread of 0.5 h is
  /// `30 min`, not `00:30`.
  final String Function(double difference)? formatChange;

  /// Writes a label of the value axis, such as `06:00`. Null for plain
  /// numbers (see `formatTickNumber`).
  final String Function(double value)? formatTick;

  /// How the daily values are drawn.
  final ChartMark mark;

  /// The daily values' name in the legend, such as `Each weigh-in`.
  final String valueLabel;

  /// What the number of values counts, such as `Nights`.
  final String countLabel;

  /// Spans to draw, one per day, such as bedtime to waking up.
  final List<DayRange> ranges;

  /// The spans' name in the legend, such as `In bed`.
  final String? rangeLabel;

  /// A limit that can change from day to day, such as the calorie limit,
  /// drawn as a dashed line: its value on each day it applies.
  final List<DayValue> limit;

  /// The limit's name in the legend.
  final String limitLabel;

  /// A recommended band, if any.
  final ReferenceBand? reference;

  /// One short line under the legend, such as the source of [reference].
  final String? note;

  /// Whether the value axis starts at zero, as it must for bars (a bar's
  /// length is its value). Measurements such as weight zoom in instead,
  /// so that their change can be seen.
  final bool startsAtZero;

  /// The value axis's fixed bottom, such as 0 for a share in percent.
  final double? fixedMin;

  /// The value axis's fixed top, such as 100 for a share in percent.
  final double? fixedMax;

  /// The steps the value axis may use between its labels, for units that
  /// do not count in tens, such as hours (`[1, 2, 3, 6]`). Null for the
  /// usual 1, 2, 2.5 and 5 times a power of ten.
  final List<double>? tickSteps;

  /// Whether the values are counts, such as reps: the value axis then
  /// never steps by less than one.
  final bool isWholeNumber;

  /// Whether each value is a total for its day, such as energy eaten or
  /// steps, so that today's value is only a total so far. Today is then
  /// drawn fainter and left out of the running mean and the summary, as
  /// Home leaves it out of its averages: half a day would pull them down.
  final bool isRunningTotal;

  /// An icon for the chart instead of its module's, such as a scale for
  /// weight under Food. Null for the module's icon.
  final IconData? icon;

  /// The first day with anything to draw, or null if there is nothing.
  DateTime? get firstDate {
    DateTime? first;
    for (final date in [
      for (final value in values) value.date,
      for (final range in ranges) range.date,
    ]) {
      if (first == null || date.isBefore(first)) {
        first = date;
      }
    }
    return first;
  }
}

/// The values of [valueOn] on each of [dates] (`YYYY-MM-DD`), oldest
/// first, leaving out days where it gives null and dates that cannot be
/// read. Each date is used once, however often it is listed.
///
/// For example, a module's weights:
/// `dailyValues(weightDates, (date) => log.weightOn(date)?.weightKg)`.
List<DayValue> dailyValues(
  Iterable<String> dates,
  double? Function(String date) valueOn,
) {
  final sortedDates = dates.toSet().toList()..sort();
  final values = <DayValue>[];
  for (final date in sortedDates) {
    final day = parseDate(date);
    final value = valueOn(date);
    if (day != null && value != null && value.isFinite) {
      values.add(DayValue(day, value));
    }
  }
  return values;
}
