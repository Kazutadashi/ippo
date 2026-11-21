// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up workouts and steps for the demo (see `demo_plan.dart`).
library;

import '../../core/dates.dart';
import '../../core/module.dart';
import 'exercise_log.dart';

/// One made-up exercise: its name, reps or seconds, its best set on the
/// first day, and its workout (push, pull or legs).
typedef _DemoExercise = ({
  String name,
  String measuredIn,
  int start,
  String workout,
});

/// A dozen common bodyweight exercises, in three workouts.
const List<_DemoExercise> _exercises = [
  (name: 'Push-up', measuredIn: 'reps', start: 12, workout: 'push'),
  (name: 'Dip', measuredIn: 'reps', start: 6, workout: 'push'),
  (name: 'Pike push-up', measuredIn: 'reps', start: 8, workout: 'push'),
  (name: 'Plank', measuredIn: 'seconds', start: 40, workout: 'push'),
  (name: 'Pull-up', measuredIn: 'reps', start: 4, workout: 'pull'),
  (name: 'Australian row', measuredIn: 'reps', start: 10, workout: 'pull'),
  (name: 'Hanging leg raise', measuredIn: 'reps', start: 6, workout: 'pull'),
  (name: 'Dead hang', measuredIn: 'seconds', start: 30, workout: 'pull'),
  (name: 'Squat', measuredIn: 'reps', start: 20, workout: 'legs'),
  (name: 'Lunge', measuredIn: 'reps', start: 12, workout: 'legs'),
  (name: 'Glute bridge', measuredIn: 'reps', start: 15, workout: 'legs'),
  (name: 'Calf raise', measuredIn: 'reps', start: 20, workout: 'legs'),
];

/// Which workout falls on a day, by how many days ago it is: push, pull,
/// legs, then a rest day, round and round. Today is a long session
/// (push and pull), so the Home tile shows more exercises than fit.
List<String> _workoutsOn(int daysAgo) {
  if (daysAgo == 0) {
    return ['push', 'pull'];
  }
  return switch (daysAgo % 4) {
    1 => ['legs'],
    2 => ['pull'],
    3 => ['push'],
    _ => [],
  };
}

/// The exercises above, trained in turn and slowly getting better (dips
/// with a little extra weight in the later weeks), and the day's steps
/// typed in each evening, slowly going up.
List<DemoEvent> exerciseDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  final ids = <String, String>{};
  for (final (index, exercise) in _exercises.indexed) {
    // A minute apart, so they keep the order of the list.
    final created = plan.event(
      plan.at(plan.firstDay, 7 + index / 60),
      exerciseModuleName,
      'exercise_created',
      {'name': exercise.name, 'measured_in': exercise.measuredIn},
    );
    ids[exercise.name] = created.id;
    events.add(created);
  }

  for (final day in plan.days) {
    final date = formatDate(day);
    final ago = plan.daysAgo(day);
    final isToday = ago == 0;
    // From 0 on the first day to 1 today.
    final progress = 1 - ago / (plan.dayCount - 1);
    final workouts = _workoutsOn(ago);
    // In the evening, but this morning today, so it shows all day.
    var minute = isToday ? 7 * 60.0 : 18 * 60.0;
    for (final exercise in _exercises) {
      if (!workouts.contains(exercise.workout)) {
        continue;
      }
      final isReps = exercise.measuredIn == 'reps';
      final best = (exercise.start * (1 + 0.4 * progress)).round();
      for (var number = 1; number <= 3; number++) {
        // Each set a little weaker than the one before.
        final value = best - (number - 1) * (isReps ? 2 : 5);
        events.add(
          plan.event(
            plan.at(day, minute / 60),
            exerciseModuleName,
            'set_recorded',
            {
              'exercise_id': ids[exercise.name],
              'date': date,
              'set_number': number,
              exercise.measuredIn: value < 1 ? 1 : value,
              // Weighted dips once they get easy.
              if (exercise.name == 'Dip' && progress > 0.5) 'weight_kg': 5,
            },
          ),
        );
        minute += 3;
      }
    }

    // Steps: typed in at night, or at lunch so far today. Slowly walking
    // more over the weeks, so Lately shows a rise.
    events.add(
      plan.event(
        plan.at(day, isToday ? 13 : 21.5),
        exerciseModuleName,
        'steps_recorded',
        {
          'date': date,
          'steps': isToday
              ? 4200 + plan.random.nextInt(1500)
              : (6000 + 3500 * progress + plan.wobble(1500)).round(),
        },
      ),
    );
  }
  return events;
}
