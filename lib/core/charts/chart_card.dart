// SPDX-License-Identifier: GPL-3.0-or-later

/// One chart as a card: its title and unit, four summary numbers for the
/// period shown, the plot, and a legend that names every mark.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import '../widgets/section_card.dart';
import 'chart_data.dart';
import 'chart_math.dart';
import 'chart_painter.dart';

/// How tall a plot is by default, axis labels included: small enough
/// that two or three charts fit on a phone screen, tall enough to see a
/// change.
const double chartPlotHeight = 128;

/// A card showing [spec] from [first] to [last].
///
/// Under the title, four numbers sum up the period: the mean, the
/// standard deviation (how much the values vary), the change per week
/// (the slope of the straight line that fits best), and how many values
/// there are. Tapping or dragging across the plot reads out one day in
/// their place; tapping that day again goes back to the summary.
class ChartCard extends StatefulWidget {
  /// Creates the card.
  const ChartCard({
    super.key,
    required this.spec,
    required this.icon,
    required this.first,
    required this.last,
    this.plotHeight = chartPlotHeight,
  });

  /// The chart.
  final ChartSpec spec;

  /// The icon before the title: the icon of the chart's module.
  final Widget icon;

  /// The first day shown.
  final DateTime first;

  /// The last day shown.
  final DateTime last;

  /// How tall the plot is, axis labels included.
  final double plotHeight;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  /// The day read out, or null to show the summary.
  DateTime? _selectedDay;

  @override
  void didUpdateWidget(ChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another period: the day read out may not be in it.
    if (oldWidget.first != widget.first || oldWidget.last != widget.last) {
      _selectedDay = null;
    }
  }

  /// Reads out the day under [x], or, tapping the day already read out,
  /// goes back to the summary.
  void _selectAt(ChartLayout layout, double x, {required bool isTap}) {
    final day = layout.dayAt(x);
    setState(() {
      _selectedDay = isTap && day == _selectedDay ? null : day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = Theme.of(context);
    final unit = spec.unit;
    final title = unit == null ? spec.title : '${spec.title} ($unit)';
    final spanDays = daysBetween(widget.first, widget.last) + 1;
    final window = meanWindowFor(spanDays);
    final plot = chartPlotFor(spec, widget.first, widget.last, window);
    final selectedDay = _selectedDay;
    return SectionCard(
      children: [
        CardHeader(
          iconWidget: spec.icon == null ? widget.icon : Icon(spec.icon),
          title: title,
        ),
        if (plot == null)
          SizedBox(
            height: widget.plotHeight,
            child: const Center(
              child: NoteText('Nothing logged in this period.'),
            ),
          )
        else ...[
          selectedDay == null
              ? _SummaryRow(spec: spec, summary: summarize(plot.countedValues))
              : _ReadoutRow(
                  spec: spec,
                  plot: plot,
                  day: selectedDay,
                  windowDays: window,
                ),
          const SizedBox(height: Spacing.small),
          _plotArea(context, plot, title),
          const SizedBox(height: Spacing.small),
          _Legend(
            spec: spec,
            windowDays: window,
            hasPartialDay: plot.values.any(
              (value) => value.date == plot.partialDay,
            ),
          ),
          if (spec.note != null) ...[
            const SizedBox(height: Spacing.tight),
            Text(
              spec.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _plotArea(BuildContext context, ChartPlot plot, String title) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall ?? const TextStyle();
    // Axis labels grow with the phone's text size, but only so far: at
    // twice the size they would leave no room for the data.
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.3);
    return SizedBox(
      height: widget.plotHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          ChartLayout layout() =>
              ChartLayout(plot, size, labelStyle, textScaler);
          return Semantics(
            label:
                'Plot of $title, ${formatShortDate(plot.first)} to '
                '${formatShortDate(plot.last)}',
            image: true,
            child: GestureDetector(
              onTapUp: (details) =>
                  _selectAt(layout(), details.localPosition.dx, isTap: true),
              onHorizontalDragUpdate: (details) =>
                  _selectAt(layout(), details.localPosition.dx, isTap: false),
              child: CustomPaint(
                size: size,
                painter: ChartPainter(
                  plot: plot,
                  colors: ChartColors.of(theme.colorScheme),
                  labelStyle: labelStyle,
                  textScaler: textScaler,
                  selectedDay: _selectedDay,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What [spec] shows from [first] to [last], with a running mean over
/// [windowDays], or null when nothing falls in that period. Shared by the
/// card and the rows of the Charts screen, so both show the same mean.
ChartPlot? chartPlotFor(
  ChartSpec spec,
  DateTime first,
  DateTime last,
  int windowDays,
) {
  final values = valuesBetween(spec.values, first, last);
  final ranges = rangesBetween(spec.ranges, first, last);
  if (values.isEmpty && ranges.isEmpty) {
    return null;
  }
  final limit = valuesBetween(spec.limit, first, last);
  // The mean is worked out over all values and then cut, so the line at
  // the left edge still counts the days just before it.
  // Today's total so far is left out of the mean (see isRunningTotal).
  final partialDay = spec.isRunningTotal ? today() : null;
  final allValues = [
    for (final value in spec.values)
      if (value.date != partialDay) value,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final mean = [
    for (final piece in runningMean(allValues, windowDays))
      valuesBetween(piece, first, last),
  ].where((piece) => piece.isNotEmpty).toList();

  // The value axis covers everything drawn.
  final shown = <double>[
    if (spec.mark != ChartMark.none) ...values.map((value) => value.value),
    for (final range in ranges) ...[range.low, range.high],
    for (final piece in mean) ...piece.map((value) => value.value),
    ...limit.map((value) => value.value),
    if (spec.reference != null) ...[spec.reference!.low, spec.reference!.high],
  ];
  final scale = niceScale(
    shown.reduce(math.min),
    shown.reduce(math.max),
    steps: spec.tickSteps,
    fixedMin: spec.fixedMin ?? (spec.startsAtZero ? 0 : null),
    fixedMax: spec.fixedMax,
    smallestStep: spec.isWholeNumber ? 1 : null,
  );
  return ChartPlot(
    first: first,
    last: last,
    values: values,
    mean: mean,
    ranges: ranges,
    limit: limit,
    reference: spec.reference,
    mark: spec.mark,
    scale: scale,
    tickLabel:
        spec.formatTick ?? (value) => formatTickNumber(value, scale.step),
    dateTicks: dateTicks(first, last),
    partialDay: partialDay,
  );
}

/// Writes a difference with [spec]'s format for changes, or its value
/// format.
String _formatChange(ChartSpec spec, double difference) =>
    (spec.formatChange ?? spec.format)(difference);

/// The four numbers summing up the period.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.spec, required this.summary});

  final ChartSpec spec;
  final ChartSummary summary;

  @override
  Widget build(BuildContext context) {
    final mean = summary.mean;
    final deviation = summary.standardDeviation;
    final change = summary.changePerWeek;
    return _StatRow(
      stats: [
        ('Mean', mean == null ? '–' : spec.format(mean)),
        ('SD', deviation == null ? '–' : _formatChange(spec, deviation)),
        ('Per week', change == null ? '–' : formatSignedChange(spec, change)),
        (spec.countLabel, '${summary.count}'),
      ],
    );
  }
}

/// A change with its sign in front: `+0.3 kg`, `−1.2 kg`, or `0 kg`
/// when it rounds to nothing.
String formatSignedChange(ChartSpec spec, double change) {
  final size = _formatChange(spec, change.abs());
  final roundsToZero = !RegExp('[1-9]').hasMatch(size);
  if (roundsToZero) {
    return size;
  }
  // The minus sign, not a hyphen, as numbers are typeset.
  return '${change < 0 ? '−' : '+'}$size';
}

/// One day read out: its value, the running mean, and its limit or span.
class _ReadoutRow extends StatelessWidget {
  const _ReadoutRow({
    required this.spec,
    required this.plot,
    required this.day,
    required this.windowDays,
  });

  final ChartSpec spec;
  final ChartPlot plot;
  final DateTime day;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final value = plot.values.where((value) => value.date == day).firstOrNull;
    final mean = [for (final piece in plot.mean) ...piece]
        .where((value) => value.date == day)
        .firstOrNull;
    final range = plot.ranges.where((range) => range.date == day).firstOrNull;
    final limit = plot.limit.where((value) => value.date == day).firstOrNull;
    final rangeText = range == null
        ? '–'
        : '${plot.tickLabel(range.low)}–${plot.tickLabel(range.high)}';
    // The year only when it is not this year's.
    final dayName = day.year == today().year
        ? formatShortDate(day)
        : '${formatShortDate(day)} ${day.year}';
    return _StatRow(
      stats: [
        if (spec.rangeLabel != null)
          (dayName, rangeText)
        else
          (dayName, _valueText(spec, plot, value)),
        if (spec.rangeLabel != null && spec.mark == ChartMark.none)
          (spec.valueLabel, value == null ? '–' : spec.format(value.value)),
        ('$windowDays-day mean', mean == null ? '–' : spec.format(mean.value)),
        if (spec.limit.isNotEmpty)
          (spec.limitLabel, limit == null ? '–' : spec.format(limit.value)),
      ],
    );
  }
}

/// A day's value as read out: `Not logged`, or the value, with `so far`
/// for today's running total.
String _valueText(ChartSpec spec, ChartPlot plot, DayValue? value) {
  if (value == null) {
    return 'Not logged';
  }
  final text = spec.format(value.value);
  return value.date == plot.partialDay ? '$text so far' : text;
}

/// Small numbers side by side, each with a grey label above: the label
/// says what the number is, so none needs explaining.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleSmall;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in stats)
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // A long value shrinks a little rather than being cut.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: valueStyle),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Names every kind of mark on the plot, with a small sample of each.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.spec,
    required this.windowDays,
    required this.hasPartialDay,
  });

  final ChartSpec spec;
  final int windowDays;

  /// Whether today's total so far is drawn, fainter.
  final bool hasPartialDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final items = <(_Swatch, String)>[
      if (spec.ranges.isNotEmpty && spec.rangeLabel != null)
        (_Swatch.range, spec.rangeLabel!),
      if (spec.mark == ChartMark.dots) (_Swatch.dot, spec.valueLabel),
      if (spec.mark == ChartMark.bars) (_Swatch.bar, spec.valueLabel),
      if (hasPartialDay && spec.mark == ChartMark.dots)
        (_Swatch.partialDot, 'Today so far'),
      if (hasPartialDay && spec.mark == ChartMark.bars)
        (_Swatch.partialBar, 'Today so far'),
      // With no daily marks, the line says what it is the mean of.
      spec.mark == ChartMark.none
          ? (
              _Swatch.line,
              '$windowDays-day mean ${spec.valueLabel.toLowerCase()}',
            )
          : (_Swatch.line, '$windowDays-day mean'),
      if (spec.limit.isNotEmpty) (_Swatch.dashes, spec.limitLabel),
      if (spec.reference != null) (_Swatch.band, spec.reference!.label),
    ];
    return Wrap(
      spacing: Spacing.medium,
      runSpacing: Spacing.tight,
      children: [
        for (final (swatch, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(16, 10),
                painter: _SwatchPainter(
                  swatch,
                  ChartColors.of(theme.colorScheme),
                ),
              ),
              const SizedBox(width: Spacing.tight),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}

/// The kinds of legend sample.
enum _Swatch { dot, bar, partialDot, partialBar, range, line, dashes, band }

/// Draws one legend sample, the way the plot draws that mark.
class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.swatch, this.colors);

  final _Swatch swatch;
  final ChartColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()..color = colors.data.withValues(alpha: 0.5);
    final fainter = Paint()..color = colors.data.withValues(alpha: 0.2);
    final middle = size.center(Offset.zero);
    switch (swatch) {
      case _Swatch.dot:
        canvas.drawCircle(middle, 2.5, faint);
      case _Swatch.bar:
        canvas.drawRect(
          Rect.fromCenter(center: middle, width: 5, height: size.height),
          faint,
        );
      case _Swatch.partialDot:
        canvas.drawCircle(middle, 2.5, fainter);
      case _Swatch.partialBar:
        canvas.drawRect(
          Rect.fromCenter(center: middle, width: 5, height: size.height),
          fainter,
        );
      case _Swatch.range:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: middle, width: 4, height: size.height),
            const Radius.circular(2),
          ),
          faint,
        );
      case _Swatch.line:
        canvas.drawLine(
          Offset(0, middle.dy),
          Offset(size.width, middle.dy),
          Paint()
            ..color = colors.data
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      case _Swatch.dashes:
        final paint = Paint()
          ..color = colors.axis
          ..strokeWidth = 1.2;
        for (var x = 0.0; x < size.width; x += 7) {
          canvas.drawLine(
            Offset(x, middle.dy),
            Offset(math.min(x + 4, size.width), middle.dy),
            paint,
          );
        }
      case _Swatch.band:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = colors.data.withValues(alpha: 0.18),
        );
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) =>
      oldDelegate.swatch != swatch || oldDelegate.colors.data != colors.data;
}
