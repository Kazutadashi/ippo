// SPDX-License-Identifier: GPL-3.0-or-later

/// A small picture of the day's habits for the home screen, quicker to
/// read than numbers: a mark, not a chart.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'habit.dart';
import 'habit_frequency.dart';
import 'habit_log.dart';

/// One dot per habit, in the habit's own color: filled when done, a ring
/// when not marked yet, a faint ring when marked not done, and a tiny dot
/// on a day it is not due (a habit not meant for every day, waiting for
/// its next turn).
class HabitBar extends StatelessWidget {
  /// Creates the dots for [habits] on [date] (`YYYY-MM-DD`).
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
      child: ExcludeSemantics(child: _rows(theme)),
    );
  }

  /// The dots in rows, left to right, top to bottom: one row for up to
  /// [_perRowLimit] habits, then two, three, up to [_rowLimit]; smaller
  /// dots the more rows there are, so the tile keeps its height.
  ///
  /// Each row is split into equal places (at least [_fewestPlaces], so a
  /// few habits keep the spacing of more), and each dot is as wide as its
  /// place allows, up to the row's biggest dot. Flexible places rather
  /// than measured widths, so Home can work out a tile's height before
  /// laying it out.
  Widget _rows(ThemeData theme) {
    final rowCount = ((habits.length / _perRowLimit).ceil()).clamp(
      1,
      _rowLimit,
    );
    final perRow = (habits.length / rowCount).ceil();
    final places = math.max(perRow, _fewestPlaces);
    final biggest = switch (rowCount) {
      1 || 2 => 16.0,
      3 => 12.0,
      _ => 9.0,
    };
    final gap = rowCount <= 2 ? 6.0 : 3.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Row(
            children: [
              for (var place = 0; place < places; place++) ...[
                if (place > 0) SizedBox(width: gap),
                Expanded(
                  child: _place(
                    theme,
                    row * perRow + place,
                    place,
                    perRow,
                    biggest,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// The dot of the habit at [index] in a place of a row, or nothing for
  /// a place past the row's habits.
  Widget _place(
    ThemeData theme,
    int index,
    int place,
    int perRow,
    double biggest,
  ) {
    if (place >= perRow || index >= habits.length) {
      return const SizedBox.shrink();
    }
    final habit = habits[index];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: biggest),
        child: AspectRatio(
          aspectRatio: 1,
          child: _Dot(
            color: habit.displayColor(theme),
            mark: log.markOn(habit.id, date),
            isDue: log.isDueOn(habit, date),
          ),
        ),
      ),
    );
  }
}

/// The most dots on one row: more habits than this go on more rows.
const int _perRowLimit = 8;

/// The most rows: past this, rows take more dots instead, so the tile
/// does not grow.
const int _rowLimit = 4;

/// The fewest places on a row, so two or three habits keep about the
/// spacing of six instead of spreading across the whole tile.
const int _fewestPlaces = 6;

/// One habit's dot: filled in its color when done, a ring of it when not
/// marked yet, a faint ring when marked not done, and a tiny dot when it
/// is not due that day.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.mark, required this.isDue});

  final Color color;
  final DayMark mark;

  /// Whether the habit is due that day; a habit waiting for its next
  /// turn (not every day) is only a tiny dot: nothing needed.
  final bool isDue;

  @override
  Widget build(BuildContext context) {
    // Waiting for its next turn and not done: a tiny dot, centered.
    if (!isDue && mark != DayMark.done) {
      return Center(
        child: FractionallySizedBox(
          widthFactor: 0.3,
          heightFactor: 0.3,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    // Done is filled; the others are only a ring, so done and not done
    // differ in shape, not only in how pale they are: easy to tell apart
    // at a glance, also with weak eyesight or color blindness.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
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

  /// The color, such as the habit's own.
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

/// The mark for a day marked not done that the habit's frequency still
/// covers, because the chain held around it (see
/// [HabitFrequency.coversDay]): a small dot in the habit's color. Quiet,
/// not a ✓, so it never looks like something to tick, and not the gray
/// ✗ of a day that broke the chain.
class CoveredMark extends StatelessWidget {
  /// Creates the mark for a grid whose marks are [size] wide, in the
  /// habit's [color].
  const CoveredMark({super.key, required this.size, required this.color});

  /// The size of the other marks, such as a ✓; the dot is half of it.
  final double size;

  /// The habit's color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size / 2,
      height: size / 2,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
    );
  }
}
