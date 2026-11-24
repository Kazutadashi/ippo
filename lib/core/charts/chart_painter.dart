// SPDX-License-Identifier: GPL-3.0-or-later

/// Draws one chart's plot: axes with round-numbered labels, light grid
/// lines, the daily values, the running mean, and any limit, band or
/// spans.
///
/// The look follows the habits of scientific plots, kept calm for a small
/// screen: the raw values are drawn faint and small, so the eye goes to
/// the running mean drawn strong over them; every axis is labeled with
/// round numbers; nothing is decorative. Everything is drawn in the
/// accent color and the theme's grays, as the rest of the app.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'chart_data.dart';
import 'chart_math.dart';

/// Everything one plot shows, already cut to the period shown.
class ChartPlot {
  /// Creates the plot's content.
  const ChartPlot({
    required this.first,
    required this.last,
    required this.values,
    required this.mean,
    required this.ranges,
    required this.limit,
    required this.reference,
    required this.mark,
    required this.scale,
    required this.tickLabel,
    required this.dateTicks,
    this.partialDay,
  });

  /// The first day shown, at the left edge.
  final DateTime first;

  /// The last day shown, at the right edge.
  final DateTime last;

  /// The daily values.
  final List<DayValue> values;

  /// The running mean, in pieces (see `runningMean`).
  final List<List<DayValue>> mean;

  /// Spans, such as nights.
  final List<DayRange> ranges;

  /// A limit, drawn dashed.
  final List<DayValue> limit;

  /// A recommended band.
  final ReferenceBand? reference;

  /// How the daily values are drawn.
  final ChartMark mark;

  /// The value axis.
  final AxisScale scale;

  /// Writes a value axis label.
  final String Function(double value) tickLabel;

  /// The date axis labels.
  final List<DateTick> dateTicks;

  /// The day whose value is only a total so far (today, for a running
  /// total), drawn fainter; null for none.
  final DateTime? partialDay;

  /// The values that count for the summary: all but [partialDay]'s.
  List<DayValue> get countedValues => [
    for (final value in values)
      if (value.date != partialDay) value,
  ];

  /// How many days are shown, counting both ends.
  int get dayCount => daysBetween(first, last) + 1;
}

/// Where the parts of a plot go in a box of a given size: the value
/// labels on the left, the date labels along the bottom, the plot area
/// in between. Shared by the painter and by the card's touch handling,
/// so a tap finds the day under the finger.
class ChartLayout {
  /// Works out the layout of [plot] in [size], with labels in
  /// [labelStyle] scaled by [textScaler].
  factory ChartLayout(
    ChartPlot plot,
    Size size,
    TextStyle labelStyle,
    TextScaler textScaler,
  ) {
    var widestLabel = 0.0;
    for (final tick in plot.scale.ticks) {
      final painter = _measure(plot.tickLabel(tick), labelStyle, textScaler);
      widestLabel = math.max(widestLabel, painter.width);
      painter.dispose();
    }
    final dateLabelHeight = _measure('0', labelStyle, textScaler);
    final bottom = dateLabelHeight.height + _labelGap;
    dateLabelHeight.dispose();
    final area = Rect.fromLTRB(
      widestLabel + _labelGap,
      // Room above the top grid line for a dot or the top of a label.
      _edgeRoom,
      size.width - _edgeRoom,
      size.height - bottom,
    );
    return ChartLayout._(plot, area);
  }

  ChartLayout._(this.plot, this.area);

  /// The plot this is the layout of.
  final ChartPlot plot;

  /// The plot area: inside the axes.
  final Rect area;

  /// The width of one day.
  double get dayWidth => area.width / plot.dayCount;

  /// The horizontal position of the middle of [day].
  double xOf(DateTime day) =>
      area.left + (daysBetween(plot.first, day) + 0.5) * dayWidth;

  /// The vertical position of [value].
  double yOf(double value) {
    final scale = plot.scale;
    final share = (value - scale.min) / (scale.max - scale.min);
    return area.bottom - share * area.height;
  }

  /// The day under the horizontal position [x], kept within the days
  /// shown.
  DateTime dayAt(double x) {
    final index = ((x - area.left) / dayWidth).floor();
    return addDays(plot.first, index.clamp(0, plot.dayCount - 1));
  }
}

/// The gap between a label and the plot.
const double _labelGap = 6;

/// Room kept free at the plot's top and right edges.
const double _edgeRoom = 6;

/// Lays out [text] once, to measure or draw it. The caller disposes it.
TextPainter _measure(String text, TextStyle style, TextScaler textScaler) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();
}

/// The colors a plot is drawn in, from the theme.
class ChartColors {
  /// Creates the colors.
  const ChartColors({
    required this.data,
    required this.grid,
    required this.axis,
    required this.label,
    required this.selection,
  });

  /// Takes the colors from [scheme]: the accent for the data, grays for
  /// the rest.
  factory ChartColors.of(ColorScheme scheme) => ChartColors(
    data: scheme.primary,
    grid: scheme.outlineVariant,
    axis: scheme.outline,
    label: scheme.onSurfaceVariant,
    selection: scheme.onSurface,
  );

  /// The data's color: the values faint, the mean line full.
  final Color data;

  /// Grid lines.
  final Color grid;

  /// The date axis line and the limit.
  final Color axis;

  /// Axis labels.
  final Color label;

  /// The line marking the day read out.
  final Color selection;
}

/// How strongly the raw values are drawn: faint enough that the mean
/// line stands out, strong enough to see each one.
const double _valueAlpha = 0.5;

/// Draws a [ChartPlot].
class ChartPainter extends CustomPainter {
  /// Creates the painter.
  ChartPainter({
    required this.plot,
    required this.colors,
    required this.labelStyle,
    required this.textScaler,
    this.selectedDay,
  });

  /// What to draw.
  final ChartPlot plot;

  /// The colors to draw it in.
  final ChartColors colors;

  /// The style of the axis labels (its color is replaced).
  final TextStyle labelStyle;

  /// How much larger text is shown.
  final TextScaler textScaler;

  /// The day read out, marked with a line, or null.
  final DateTime? selectedDay;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = ChartLayout(plot, size, labelStyle, textScaler);
    _paintBand(canvas, layout);
    _paintValueAxis(canvas, layout);
    _paintDateAxis(canvas, layout, size);
    canvas.save();
    // Data outside a fixed axis (over 100 %) is cut at the edge rather
    // than drawn over the labels.
    canvas.clipRect(layout.area.inflate(_edgeRoom));
    _paintRanges(canvas, layout);
    _paintValues(canvas, layout);
    _paintLimit(canvas, layout);
    _paintMean(canvas, layout);
    _paintSelection(canvas, layout);
    canvas.restore();
  }

  void _paintBand(Canvas canvas, ChartLayout layout) {
    final reference = plot.reference;
    if (reference == null) {
      return;
    }
    final top = layout
        .yOf(reference.high)
        .clamp(layout.area.top, layout.area.bottom);
    final bottom = layout
        .yOf(reference.low)
        .clamp(layout.area.top, layout.area.bottom);
    canvas.drawRect(
      Rect.fromLTRB(layout.area.left, top, layout.area.right, bottom),
      Paint()..color = colors.data.withValues(alpha: 0.10),
    );
  }

  /// Grid lines across at each round value, labeled on the left.
  void _paintValueAxis(Canvas canvas, ChartLayout layout) {
    final gridPaint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    final style = labelStyle.copyWith(color: colors.label);
    for (final tick in plot.scale.ticks) {
      final y = layout.yOf(tick);
      canvas.drawLine(
        Offset(layout.area.left, y),
        Offset(layout.area.right, y),
        gridPaint,
      );
      final label = _measure(plot.tickLabel(tick), style, textScaler);
      label.paint(
        canvas,
        Offset(
          layout.area.left - _labelGap - label.width,
          y - label.height / 2,
        ),
      );
      label.dispose();
    }
  }

  /// The date axis: a line along the bottom, a faint line up at each
  /// label, and the labels, skipping any that would touch the one before.
  void _paintDateAxis(Canvas canvas, ChartLayout layout, Size size) {
    final area = layout.area;
    canvas.drawLine(
      Offset(area.left, area.bottom),
      Offset(area.right, area.bottom),
      Paint()
        ..color = colors.axis
        ..strokeWidth = 1,
    );
    final gridPaint = Paint()
      ..color = colors.grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final tickPaint = Paint()
      ..color = colors.axis
      ..strokeWidth = 1;
    final style = labelStyle.copyWith(color: colors.label);
    var labelsEnd = double.negativeInfinity;
    for (final tick in plot.dateTicks) {
      // A tick sits at the start of its day: the month begins there.
      final x = layout.xOf(tick.date) - layout.dayWidth / 2;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), gridPaint);
      canvas.drawLine(
        Offset(x, area.bottom),
        Offset(x, area.bottom + 3),
        tickPaint,
      );
      final label = _measure(tick.label, style, textScaler);
      final left = (x - label.width / 2).clamp(0.0, size.width - label.width);
      if (left > labelsEnd + 4) {
        label.paint(canvas, Offset(left, area.bottom + _labelGap - 2));
        labelsEnd = left + label.width;
      }
      label.dispose();
    }
  }

  void _paintRanges(Canvas canvas, ChartLayout layout) {
    if (plot.ranges.isEmpty) {
      return;
    }
    final width = math.max(1.5, layout.dayWidth * 0.6);
    final paint = Paint()..color = colors.data.withValues(alpha: _valueAlpha);
    for (final range in plot.ranges) {
      final x = layout.xOf(range.date);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x - width / 2,
            layout.yOf(range.high),
            x + width / 2,
            layout.yOf(range.low),
          ),
          Radius.circular(math.min(width / 2, 2)),
        ),
        paint,
      );
    }
  }

  void _paintValues(Canvas canvas, ChartLayout layout) {
    final paint = Paint()..color = colors.data.withValues(alpha: _valueAlpha);
    // A total so far is drawn fainter: it is not the day's whole value.
    final partialPaint = Paint()
      ..color = colors.data.withValues(alpha: _valueAlpha / 2.5);
    Paint paintFor(DayValue value) =>
        value.date == plot.partialDay ? partialPaint : paint;
    switch (plot.mark) {
      case ChartMark.none:
        return;
      case ChartMark.bars:
        // A gap between bars while there is room for one.
        final width = layout.dayWidth >= 3
            ? layout.dayWidth * 0.7
            : math.max(1.0, layout.dayWidth);
        final zero = layout.yOf(math.max(0, plot.scale.min));
        for (final value in plot.values) {
          final x = layout.xOf(value.date);
          canvas.drawRect(
            Rect.fromLTRB(
              x - width / 2,
              layout.yOf(value.value),
              x + width / 2,
              zero,
            ),
            paintFor(value),
          );
        }
      case ChartMark.dots:
        // Smaller dots when many days share the width.
        final radius = layout.dayWidth >= 4 ? 2.5 : 1.6;
        for (final value in plot.values) {
          canvas.drawCircle(
            Offset(layout.xOf(value.date), layout.yOf(value.value)),
            radius,
            paintFor(value),
          );
        }
    }
  }

  /// The limit as a dashed line, stepping where it changes.
  void _paintLimit(Canvas canvas, ChartLayout layout) {
    if (plot.limit.isEmpty) {
      return;
    }
    final path = Path();
    DayValue? previous;
    for (final value in plot.limit) {
      final left = layout.xOf(value.date) - layout.dayWidth / 2;
      final right = left + layout.dayWidth;
      final y = layout.yOf(value.value);
      final continues =
          previous != null && daysBetween(previous.date, value.date) == 1;
      if (continues) {
        path.lineTo(left, y);
      } else {
        path.moveTo(left, y);
      }
      path.lineTo(right, y);
      previous = value;
    }
    _drawDashed(
      canvas,
      path,
      Paint()
        ..color = colors.axis
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintMean(Canvas canvas, ChartLayout layout) {
    final paint = Paint()
      ..color = colors.data
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final piece in plot.mean) {
      if (piece.length == 1) {
        // A one-day piece is a short dash, so it still shows.
        final x = layout.xOf(piece.first.date);
        final y = layout.yOf(piece.first.value);
        canvas.drawLine(Offset(x - 2, y), Offset(x + 2, y), paint);
        continue;
      }
      final path = Path();
      for (final (index, value) in piece.indexed) {
        final point = Offset(layout.xOf(value.date), layout.yOf(value.value));
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  /// A thin line up through the day read out, and a ring on its value.
  void _paintSelection(Canvas canvas, ChartLayout layout) {
    final day = selectedDay;
    if (day == null) {
      return;
    }
    final x = layout.xOf(day);
    canvas.drawLine(
      Offset(x, layout.area.top),
      Offset(x, layout.area.bottom),
      Paint()
        ..color = colors.selection.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );
    for (final value in plot.values) {
      if (value.date == day && plot.mark != ChartMark.none) {
        canvas.drawCircle(
          Offset(x, layout.yOf(value.value)),
          4,
          Paint()
            ..color = colors.selection
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) =>
      oldDelegate.plot != plot ||
      oldDelegate.selectedDay != selectedDay ||
      oldDelegate.colors.data != colors.data ||
      oldDelegate.colors.grid != colors.grid ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler;
}

/// Draws [path] as dashes of 4 with gaps of 3.
void _drawDashed(Canvas canvas, Path path, Paint paint) {
  for (final metric in path.computeMetrics()) {
    for (var start = 0.0; start < metric.length; start += 7) {
      canvas.drawPath(
        metric.extractPath(start, math.min(start + 4, metric.length)),
        paint,
      );
    }
  }
}
