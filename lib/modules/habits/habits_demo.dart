// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up habits for the demo (see `demo_plan.dart`).
library;

import '../../core/dates.dart';
import '../../core/module.dart';
import 'habit_log.dart';

/// One made-up habit: its name, its colour (`#RRGGBB`, or null for the
/// accent colour), how often it gets done (0 to 1), how many days ago it
/// was started (null for the first day of the demo), and the name it
/// had before being renamed a few days in (null if never renamed).
typedef _DemoHabit = ({
  String name,
  String? color,
  double chance,
  int? startedDaysAgo,
  String? formerName,
});

/// A dozen everyday habits, in colours all around the wheel (so "By
/// colour" has something to sort), some kept up nearly every day and
/// some hard, one started only last week.
const List<_DemoHabit> _habits = [
  (
    name: 'Read 10 pages',
    color: '#43A047',
    chance: 0.9,
    startedDaysAgo: null,
    formerName: 'Read',
  ),
  (
    name: 'Stretch',
    color: '#1E88E5',
    chance: 0.65,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Walk outside',
    color: '#FB8C00',
    chance: 0.8,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Drink water',
    color: null,
    chance: 0.95,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Journal',
    color: '#8E24AA',
    chance: 0.45,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Meditate',
    color: '#00897B',
    chance: 0.6,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Floss',
    color: '#00ACC1',
    chance: 0.7,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Vitamins',
    color: '#FFB300',
    chance: 0.85,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'No phone in bed',
    color: '#3949AB',
    chance: 0.4,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Practise Spanish',
    color: '#E53935',
    chance: 0.7,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Make the bed',
    color: '#6D4C41',
    chance: 0.9,
    startedDaysAgo: null,
    formerName: null,
  ),
  (
    name: 'Cook dinner',
    color: '#D81B60',
    chance: 0.55,
    startedDaysAgo: 8,
    formerName: null,
  ),
];

/// Every habit above, kept up most days, with today's likely ones
/// already ticked off; one of them renamed a few days in. Also one habit
/// given up (archived) and one deleted, so those show as they should:
/// hidden.
List<DemoEvent> habitsDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  for (final habit in _habits) {
    final started = habit.startedDaysAgo == null
        ? plan.firstDay
        : addDays(plan.today, -habit.startedDaysAgo!);
    final created = plan.event(
      plan.at(started, 8),
      habitsModuleName,
      'habit_created',
      {
        'name': habit.formerName ?? habit.name,
        'value_type': 'yes_no',
        'frequency': {'times': 1, 'per_days': 1},
        if (habit.color != null) 'color': habit.color,
      },
    );
    events.add(created);
    if (habit.formerName != null) {
      // Renamed a few days in: shown under the new name, with all days.
      events.add(
        plan.event(
          plan.at(addDays(started, 4), 8),
          habitsModuleName,
          'habit_changed',
          {
            'target_id': created.id,
            'changes': {'name': habit.name},
          },
        ),
      );
    }
    for (final day in plan.days) {
      if (day.isBefore(started)) {
        continue;
      }
      final isToday = plan.daysAgo(day) == 0;
      // Today, only the likely ones are done yet, in the morning.
      if (isToday && habit.chance < 0.8) {
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
            'value': plan.chance(habit.chance),
          },
        ),
      );
    }
  }

  // A habit given up after the first week: archived, so it is hidden.
  final givenUp = plan.event(
    plan.at(plan.firstDay, 8),
    habitsModuleName,
    'habit_created',
    {
      'name': 'Cold shower',
      'value_type': 'yes_no',
      'frequency': {'times': 1, 'per_days': 1},
      'color': '#757575',
    },
  );
  events
    ..add(givenUp)
    ..add(
      plan.event(
        plan.at(addDays(plan.firstDay, 7), 9),
        habitsModuleName,
        'habit_changed',
        {
          'target_id': givenUp.id,
          'changes': {'archived': true},
        },
      ),
    );

  // A habit added by mistake and deleted the same day: hidden.
  final mistake = plan.event(
    plan.at(addDays(plan.firstDay, 3), 10),
    habitsModuleName,
    'habit_created',
    {
      'name': 'Strech',
      'value_type': 'yes_no',
      'frequency': {'times': 1, 'per_days': 1},
    },
  );
  events
    ..add(mistake)
    ..add(
      plan.event(
        plan.at(addDays(plan.firstDay, 3), 10.05),
        habitsModuleName,
        'habit_deleted',
        {'target_id': mistake.id},
      ),
    );

  return events;
}
