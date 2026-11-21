// SPDX-License-Identifier: GPL-3.0-or-later

/// A small picture of the day's habits for the home screen, quicker to
/// read than numbers: a mark, not a chart.
library;

import 'package:material_ui/material_ui.dart';

import 'habit.dart';
import 'habit_log.dart';

/// A bar across the tile with one segment per habit, in the habit's own
/// colour: filled when done, a faint tint when not marked yet, and
/// fainter still when marked not done.
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
        // One bar across the tile, a segment per habit, like the bars
        // of the other tiles.
        child: Row(
          children: [
            for (final (index, habit) in habits.indexed) ...[
              if (index > 0) SizedBox(width: habits.length > 10 ? 2 : 4),
              Expanded(
                child: _Segment(
                  color: habit.displayColor(theme),
                  mark: log.markOn(habit.id, date),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One habit's part of the bar: filled in its colour when done, a faint
/// tint of it when not marked yet, and fainter still when marked not
/// done, so what is still open stands out from what was skipped.
class _Segment extends StatelessWidget {
  const _Segment({required this.color, required this.mark});

  final Color color;
  final DayMark mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: switch (mark) {
          DayMark.done => color,
          DayMark.none => color.withValues(alpha: 0.16),
          DayMark.notDone => color.withValues(alpha: 0.07),
        },
      ),
    );
  }
}
