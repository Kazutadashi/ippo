// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up habits for the demo (see `demo_plan.dart`).
library;

import 'dart:math';

import '../../core/dates.dart';
import '../../core/module.dart';
import 'habit_frequency.dart';
import 'habit_log.dart';

/// One made-up habit: its name, its colour (`#RRGGBB`, or null for the
/// accent colour), how often it gets done (0 to 1), how many days ago it
/// was started (null for the first day of the demo), the name it had
/// before being renamed a few days in (null if never renamed), and how
/// often it is meant to be done.
typedef _DemoHabit = ({
  String name,
  String? color,
  double chance,
  int? startedDaysAgo,
  String? formerName,
  HabitFrequency frequency,
});

/// What a few of the demo habits mean, as a user would write it, so the
/// habit form shows one.
const Map<String, String> _descriptions = {
  'Walk outside': 'At least 20 minutes, whatever the weather.',
  'Drink water': 'Eight glasses over the day.',
};

/// A dozen everyday habits, in colours all around the wheel (so "By
/// colour" has something to sort), some kept up nearly every day and
/// some hard, one started only last week, and four not meant for every
/// day (three times a week, twice a week, every 3 days, once a week).
const List<_DemoHabit> _habits = [
  (
    name: 'Read 10 pages',
    color: '#43A047',
    chance: 0.9,
    startedDaysAgo: null,
    formerName: 'Read',
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Stretch',
    color: '#1E88E5',
    chance: 0.65,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Walk outside',
    color: '#FB8C00',
    chance: 0.8,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Drink water',
    color: null,
    chance: 0.95,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Journal',
    color: '#8E24AA',
    chance: 0.45,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Meditate',
    color: '#00897B',
    chance: 0.6,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Water the plants',
    color: '#00ACC1',
    chance: 0.7,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency(1, 3),
  ),
  (
    name: 'Vitamins',
    color: '#FFB300',
    chance: 0.85,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'No phone in bed',
    color: '#3949AB',
    chance: 0.4,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency.everyDay,
  ),
  (
    name: 'Practise Spanish',
    color: '#E53935',
    chance: 0.7,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency(3, 7),
  ),
  (
    name: 'Call family',
    color: '#6D4C41',
    chance: 0.9,
    startedDaysAgo: null,
    formerName: null,
    frequency: HabitFrequency(1, 7),
  ),
  (
    name: 'Cook dinner',
    color: '#D81B60',
    chance: 0.55,
    startedDaysAgo: 8,
    formerName: null,
    frequency: HabitFrequency(2, 7),
  ),
];

/// Every habit above, kept up most days, with today's likely ones
/// already ticked off; one of them renamed a few days in. Also one habit
/// given up (archived) and one deleted, so those show as they should:
/// hidden.
List<DemoEvent> habitsDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  // Ids for the ✗ on waiting days, added later: their own random
  // numbers, so the rest of the demo did not change with them.
  final waitingDayIds = Random(3);
  for (final (index, habit) in _habits.indexed) {
    final started = habit.startedDaysAgo == null
        ? plan.firstDay
        : addDays(plan.today, -habit.startedDaysAgo!);
    // A minute apart, so they keep the order of the list (habits made at
    // the very same moment would be ordered by their random ids).
    final created = plan.event(
      plan.at(started, 8 + index / 60),
      habitsModuleName,
      'habit_created',
      {
        'name': habit.formerName ?? habit.name,
        'value_type': 'yes_no',
        'frequency': habit.frequency.toJson(),
        if (habit.color != null) 'color': habit.color,
        if (_descriptions[habit.name] case final description?)
          'description': description,
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
    // The days it was done so far, to know when a habit that is not for
    // every day is due again.
    final doneDays = <DateTime>[];
    for (final day in plan.days) {
      if (day.isBefore(started)) {
        continue;
      }
      final isToday = plan.daysAgo(day) == 0;
      // Today, only the likely ones are done yet, in the morning.
      if (isToday && habit.chance < 0.8) {
        continue;
      }
      // A waiting day (done often enough lately): usually nothing to
      // record, but every third day of the month a ✗, as people tap;
      // where the chain holds around it, the grid shows it as covered.
      // Picked by date, not by chance, so the rest of the demo stays
      // the same.
      final window = habit.frequency.perDays;
      final doneLately = doneDays
          .where((done) => day.difference(done).inDays < window)
          .length;
      if (doneLately >= habit.frequency.times) {
        if (!isToday && day.day % 3 == 0) {
          events.add(
            plan.event(
              plan.at(day, 21),
              habitsModuleName,
              'habit_entry_recorded',
              {'habit_id': created.id, 'date': formatDate(day), 'value': false},
              idRandom: waitingDayIds,
            ),
          );
        }
        continue;
      }
      final isDone = plan.chance(habit.chance);
      if (isDone) {
        doneDays.add(day);
      }
      events.add(
        plan.event(
          plan.at(day, isToday ? 8.5 : 21),
          habitsModuleName,
          'habit_entry_recorded',
          {'habit_id': created.id, 'date': formatDate(day), 'value': isDone},
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
