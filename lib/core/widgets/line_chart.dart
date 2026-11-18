// SPDX-License-Identifier: GPL-3.0-or-later

/// A small line chart of values over days, drawn by hand so the app
/// needs no chart library.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import '../number_input.dart';

/// One value on one day.
class DayValue {
  /// Creates a point: [value] on [date] (`YYYY-MM-DD`).
  const DayValue(this.date, this.value);

  /// The day, `YYYY-MM-DD`.
  final String date;

  /// The value on that day.
  final double value;
}

/// Draws [points] as a line, with days spaced by real time: a week
/// without data is a visible gap, not squeezed away.
class DayLineChart extends StatelessWidget {
  /// Creates a chart of [points], which must be sorted by date.
  const DayLineChart({super.key, required this.points, this.height = 180});

  /// The values to draw, oldest first. Points with invalid dates are
  /// skipped.
  final List<DayValue> points;

  /// The chart's height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usable = points.where((point) => parseDate(point.date) != null);
    if (usable.length < 2) {
      return SizedBox(
        height: height / 2,
        child: const Center(
          child: Text('The chart appears after two days with data.'),
        ),
      );
    }

    final values = usable.map((point) => point.value);
    final highest = values.reduce(max);
    final lowest = min(0.0, values.reduce(min));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatAmount(highest), style: textTheme.bodySmall),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: usable.toList(),
              lowest: lowest,
              highest: highest,
              lineColor: colors.primary,
              axisColor: colors.outlineVariant,
            ),
          ),
        ),
        Row(
          children: [
            Text(formatAmount(lowest), style: textTheme.bodySmall),
            const Spacer(),
            Text(
              '${usable.first.date} – ${usable.last.date}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// Paints the axis, the line and a dot for each point.
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.lowest,
    required this.highest,
    required this.lineColor,
    required this.axisColor,
  });

  final List<DayValue> points;
  final double lowest;
  final double highest;
  final Color lineColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final firstDay = parseDate(points.first.date)!;
    final lastDay = parseDate(points.last.date)!;
    // Count whole days; at least 1 so a single day does not divide by 0.
    final daySpan = max(1, lastDay.difference(firstDay).inHours / 24);
    final valueSpan = highest - lowest == 0 ? 1 : highest - lowest;

    Offset placeOf(DayValue point) {
      final day = parseDate(point.date)!;
      final dayOffset = day.difference(firstDay).inHours / 24;
      final x = size.width * dayOffset / daySpan;
      // Screen y grows downwards, so high values get small y.
      final y = size.height * (1 - (point.value - lowest) / valueSpan);
      return Offset(x, y);
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final place = placeOf(points[index]);
      if (index == 0) {
        path.moveTo(place.dx, place.dy);
      } else {
        path.lineTo(place.dx, place.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(placeOf(point), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor;
  }
}
