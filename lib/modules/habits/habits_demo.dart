// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up habits for the demo (see `demo_plan.dart`).
library;

import '../../core/dates.dart';
import '../../core/module.dart';
import 'habit_log.dart';

/// Five everyday habits, kept up most days, with a few of today's
/// already ticked off.
List<DemoEvent> habitsDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  // Each habit: its name, its colour (null for the accent colour), and
  // how often it gets done, from 0 to 1.
  const habits = [
    ('Read 10 pages', '#43A047', 0.9),
    ('Stretch', '#1E88E5', 0.65),
    ('Walk outside', '#FB8C00', 0.8),
    ('Drink water', null, 0.95),
    ('Journal', '#8E24AA', 0.45),
  ];
  for (final (name, color, chance) in habits) {
    final created = plan.event(
      plan.at(plan.firstDay, 8),
      habitsModuleName,
      'habit_created',
      {
        'name': name,
        'value_type': 'yes_no',
        'frequency': {'times': 1, 'per_days': 1},
        if (color != null) 'color': color,
      },
    );
    events.add(created);
    for (final day in plan.days) {
      final isToday = plan.daysAgo(day) == 0;
      // Today, only the likely ones are done yet, in the morning.
      if (isToday && chance < 0.8) {
        continue;
      }
      events.add(
        plan.event(
          plan.at(day, isToday ? 8.5 : 21),
          habitsModuleName,
          'habit_entry_recorded',
          {
            'habit_id': created.id,
            'date': formatDate(day),
            'value': plan.chance(chance),
          },
        ),
      );
    }
  }
  return events;
}
