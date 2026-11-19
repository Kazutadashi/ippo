// SPDX-License-Identifier: GPL-3.0-or-later

/// Small pictures of habits for the home screen: dots and squares that
/// are quicker to read than numbers. They are marks, not charts.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
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

/// The last seven days of one habit, as small squares, oldest first:
/// filled when done (older days a little fainter), an outline otherwise.
class StreakSquares extends StatelessWidget {
  /// Creates the squares for [habit], ending on [day].
  const StreakSquares({
    super.key,
    required this.habit,
    required this.log,
    required this.day,
  });

  /// The habit.
  final Habit habit;

  /// Where its marks come from.
  final HabitLog log;

  /// The last day shown.
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final color = habit.displayColor(Theme.of(context));
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var back = 6; back >= 0; back--) ...[
            _square(
              color,
              isDone:
                  log.markOn(habit.id, formatDate(addDays(day, -back))) ==
                  DayMark.done,
              // Today strongest, the oldest day faintest.
              strength: 1 - back * 0.09,
            ),
            if (back > 0) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }

  Widget _square(
    Color color, {
    required bool isDone,
    required double strength,
  }) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: isDone ? color.withValues(alpha: strength) : null,
        border: isDone
            ? null
            : Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
    );
  }
}

/// Seven dots for the days ending on [day], each as full as the share of
/// habits done that day, with the weekday's letter below.
class HabitWeekStrip extends StatelessWidget {
  /// Creates the strip.
  const HabitWeekStrip({
    super.key,
    required this.habits,
    required this.log,
    required this.day,
    required this.baseColor,
  });

  /// The habits counted.
  final List<Habit> habits;

  /// Where their marks come from.
  final HabitLog log;

  /// The last day shown.
  final DateTime day;

  /// The habits module's colour, before toning.
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = moduleTone(baseColor, theme.brightness);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var back = 6; back >= 0; back--)
            Expanded(
              child: Column(
                children: [
                  _dayDot(color, _shareDone(addDays(day, -back))),
                  const SizedBox(height: 2),
                  Text(
                    letters[addDays(day, -back).weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The share of habits done on [date], from 0 to 1.
  double _shareDone(DateTime date) {
    final text = formatDate(date);
    final done = habits
        .where((habit) => log.markOn(habit.id, text) == DayMark.done)
        .length;
    return done / habits.length;
  }

  Widget _dayDot(Color color, double share) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: share == 0 ? null : color.withValues(alpha: 0.25 + 0.75 * share),
        border: share == 0 ? Border.all(color: color, width: 1.5) : null,
      ),
    );
  }
}
