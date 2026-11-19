// SPDX-License-Identifier: GPL-3.0-or-later

/// Small pictures of habits for the home screen: dots and squares that
/// are quicker to read than numbers. They are marks, not charts.
library;

import 'package:material_ui/material_ui.dart';

import 'habit.dart';
import 'habit_log.dart';

/// One dot per habit, in the habit's own colour: filled when done, an
/// empty ring when not marked yet, and a faint ring when marked not done.
class HabitDots extends StatelessWidget {
  /// Creates the dots for [habits] on [date] (`YYYY-MM-DD`).
  const HabitDots({
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
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final habit in habits)
              _Dot(
                color: habit.displayColor(theme),
                mark: log.markOn(habit.id, date),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.mark});

  final Color color;
  final DayMark mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mark == DayMark.done ? color : null,
        border: mark == DayMark.done
            ? null
            : Border.all(
                color: mark == DayMark.notDone
                    ? color.withValues(alpha: 0.35)
                    : color,
                width: 1.5,
              ),
      ),
    );
  }
}
