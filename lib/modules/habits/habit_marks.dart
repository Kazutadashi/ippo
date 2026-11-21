// SPDX-License-Identifier: GPL-3.0-or-later

/// A small picture of the day's habits for the home screen, quicker to
/// read than numbers: a mark, not a chart.
library;

import 'package:material_ui/material_ui.dart';

import 'habit.dart';
import 'habit_log.dart';

/// A bar across the tile with one segment per habit, in the habit's own
/// colour: filled when done, an outline when not marked yet, a faint
/// outline when marked not done, and a thin line on a day it is not due
/// (a habit not meant for every day, waiting for its next turn).
class HabitBar extends StatelessWidget {
  /// Creates the bar for [habits] on [date] (`YYYY-MM-DD`).
  const HabitBar({
    super.key,
    required this.habits,
    required this.log,
    required this.date,
  });

  /// The habits, in their usual order.
  final List<Habit> habits;

  /// Where their marks come from.
  final HabitLog log;

  /// The day shown.
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = [
      for (final habit in habits)
        if (log.markOn(habit.id, date) == DayMark.done) habit.name,
    ];
    return Semantics(
      label: done.isEmpty ? 'None done yet' : 'Done: ${done.join(', ')}',
      child: ExcludeSemantics(
        // A bar across the tile, a segment per habit, like the bars of
        // the other tiles. Many habits go on more rows, so a segment is
        // never too thin to see.
        child: _rows(theme),
      ),
    );
  }

  /// The habits in rows of about equal length: one row for up to
  /// [_perRowLimit] habits, then two, three, up to [_rowLimit]. A short
  /// last row keeps the same segment width as the others. Rows are a
  /// little thinner the more there are, so the tile keeps its height.
  Widget _rows(ThemeData theme) {
    final rowCount = ((habits.length / _perRowLimit).ceil()).clamp(
      1,
      _rowLimit,
    );
    final perRow = (habits.length / rowCount).ceil();
    final height = switch (rowCount) {
      1 => 10.0,
      2 => 8.0,
      _ => 6.0,
    };
    final gap = perRow > 10 ? 2.0 : 4.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Row(
            children: [
              for (var column = 0; column < perRow; column++) ...[
                if (column > 0) SizedBox(width: gap),
                Expanded(
                  child: row * perRow + column < habits.length
                      ? _Segment(
                          color: habits[row * perRow + column].displayColor(
                            theme,
                          ),
                          mark: log.markOn(
                            habits[row * perRow + column].id,
                            date,
                          ),
                          isDue: log.isDueOn(
                            habits[row * perRow + column],
                            date,
                          ),
                          height: height,
                        )
                      // An empty place, so the last row's segments are as
                      // wide as the others.
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// The most segments on one row of the bar: more habits than this go
/// on more rows.
const int _perRowLimit = 8;

/// The most rows: past this, rows take more segments instead, so the
/// tile does not grow.
const int _rowLimit = 4;

/// One habit's part of the bar: filled in its colour when done, an
/// outline of it when not marked yet, a faint outline when marked not
/// done, and a thin line when it is not due that day.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.color,
    required this.mark,
    required this.isDue,
    required this.height,
  });

  final Color color;
  final DayMark mark;

  /// Whether the habit is due that day; a habit waiting for its next
  /// turn (not every day) is only a thin line: nothing needed.
  final bool isDue;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Waiting for its next turn and not done: a thin line, centred.
    if (!isDue && mark != DayMark.done) {
      return SizedBox(
        height: height,
        child: Center(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }
    // Done is filled; the others are only an outline, so done and not
    // done differ in shape, not only in how pale they are: easy to tell
    // apart at a glance, also with weak eyesight or colour blindness.
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: mark == DayMark.done ? color : null,
        border: mark == DayMark.done
            ? null
            : Border.all(
                color: color.withValues(
                  alpha: mark == DayMark.none ? 0.8 : 0.3,
                ),
                width: 1.5,
              ),
      ),
    );
  }
}

/// A check mark with a thick, rounded stroke: Material's ✓ is thin and
/// hard to see at a glance in a grid.
class BoldCheck extends StatelessWidget {
  /// Creates the mark.
  const BoldCheck({super.key, required this.size, required this.color});

  /// The width and height.
  final double size;

  /// The colour, such as the habit's own.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CheckPainter(color)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // The short stroke down to the bottom, then the long one up.
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.54)
      ..lineTo(size.width * 0.40, size.height * 0.76)
      ..lineTo(size.width * 0.86, size.height * 0.26);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.color != color;
}
