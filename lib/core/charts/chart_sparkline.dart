// SPDX-License-Identifier: GPL-3.0-or-later

/// A small line without axes: a chart's running mean over the last few
/// weeks, so a row on the Charts screen shows at a glance which way a
/// measure is going.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'chart_data.dart';
import 'chart_painter.dart';

/// Draws the running mean of a [ChartPlot] as a small line, scaled to
/// its own highest and lowest values, with a dot on the latest. Without
/// axes it only shows a shape: the row next to it gives the numbers.
class ChartSparkline extends StatelessWidget {
  /// Creates the line for [plot].
  const ChartSparkline({super.key, required this.plot});

  /// What to draw; only its running mean is used.
  final ChartPlot plot;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size(64, 24),
        painter: _SparklinePainter(plot, Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.plot, this.color);

  final ChartPlot plot;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [for (final piece in plot.mean) ...piece];
    if (points.isEmpty) {
      return;
    }
    var low = points.first.value;
    var high = points.first.value;
    for (final point in points) {
      low = math.min(low, point.value);
      high = math.max(high, point.value);
    }
    // A flat line sits in the middle rather than at the bottom.
    final spread = high - low;
    const dotRoom = 2.5;
    final dayWidth = (size.width - 2 * dotRoom) / plot.dayCount;
    Offset place(DayValue value) {
      final x =
          dotRoom + (daysBetween(plot.first, value.date) + 0.5) * dayWidth;
      final share = spread == 0 ? 0.5 : (value.value - low) / spread;
      return Offset(
        x,
        size.height - dotRoom - share * (size.height - 2 * dotRoom),
      );
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (final piece in plot.mean) {
      final path = Path();
      for (final (index, value) in piece.indexed) {
        final point = place(value);
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, linePaint);
    }
    canvas.drawCircle(place(points.last), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.plot != plot || oldDelegate.color != color;
}
