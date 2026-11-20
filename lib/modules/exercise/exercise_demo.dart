// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up workouts and steps for the demo (see `demo_plan.dart`).
library;

import '../../core/dates.dart';
import '../../core/module.dart';
import 'exercise_log.dart';

/// Four bodyweight exercises, trained every other day and slowly
/// getting better, and the day's steps typed in each evening, slowly
/// going up.
List<DemoEvent> exerciseDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  // Each exercise: its name, reps or seconds, and the best set on the
  // first day.
  const exercises = [
    ('Push-up', 'reps', 12),
    ('Squat', 'reps', 20),
    ('Pull-up', 'reps', 4),
    ('Plank', 'seconds', 40),
  ];
  final ids = <String, String>{};
  for (final (name, measuredIn, _) in exercises) {
    final created = plan.event(
      plan.at(plan.firstDay, 18),
      exerciseModuleName,
      'exercise_created',
      {'name': name, 'measured_in': measuredIn},
    );
    ids[name] = created.id;
    events.add(created);
  }

  for (final day in plan.days) {
    final date = formatDate(day);
    final ago = plan.daysAgo(day);
    // From 0 on the first day to 1 today.
    final progress = 1 - ago / (plan.dayCount - 1);
    if (ago.isEven) {
      var minute = 0.0;
      for (final (name, measuredIn, start) in exercises) {
        final best = (start * (1 + 0.4 * progress)).round();
        final setCount = measuredIn == 'reps' ? 3 : 2;
        for (var number = 1; number <= setCount; number++) {
          // Each set a little weaker than the one before.
          final value = best - (number - 1) * (measuredIn == 'reps' ? 2 : 5);
          events.add(
            plan.event(
              plan.at(day, 18 + minute / 60),
              exerciseModuleName,
              'set_recorded',
              {
                'exercise_id': ids[name],
                'date': date,
                'set_number': number,
                measuredIn: value < 1 ? 1 : value,
              },
            ),
          );
          minute += 3;
        }
      }
    }
    // Steps: typed in at night, or at lunch so far today.
    final isToday = ago == 0;
    events.add(
      plan.event(
        plan.at(day, isToday ? 13 : 21.5),
        exerciseModuleName,
        'steps_recorded',
        {
          'date': date,
          // Slowly walking more over the weeks, so Lately shows a rise.
          'steps': isToday
              ? 4200 + plan.random.nextInt(1500)
              : (6000 + 3500 * progress + plan.wobble(1500)).round(),
        },
      ),
    );
  }
  return events;
}
