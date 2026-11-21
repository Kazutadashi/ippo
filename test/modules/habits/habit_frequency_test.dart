// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for habits not meant for every day: [HabitFrequency], due days
/// and streaks.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/events/event.dart';
import 'package:ippo/modules/habits/habit_frequency.dart';
import 'package:ippo/modules/habits/habit_log.dart';

void main() {
  var counter = 0;

  /// One event line, as a device writes it.
  Event event(String type, Map<String, Object?> data, {String? id}) {
    counter++;
    final seconds = counter.toString().padLeft(2, '0');
    return Event.fromJsonLine(
      jsonEncode({
        'format_version': 1,
        'id':
            id ??
            '0190a000-0000-7000-8000-${counter.toString().padLeft(12, '0')}',
        'recorded_at': '2026-11-01T08:00:$seconds.000+00:00',
        'device_id': '0190a000-0000-7000-8000-00000000aaaa',
        'device_name': 'my-phone',
        'module': 'habits',
        'type': type,
        'data': data,
      }),
    );
  }

  const habitId = '0190a000-0000-7000-8000-00000000babe';

  /// A habit "every 3 days" ([frequency]), done on [doneDates].
  HabitLog logWith(Map<String, Object?> frequency, List<String> doneDates) {
    counter = 0;
    return HabitLog.fromEvents([
      event('habit_created', {
        'name': 'Water the plants',
        'value_type': 'yes_no',
        'frequency': frequency,
      }, id: habitId),
      for (final date in doneDates)
        event('habit_entry_recorded', {
          'habit_id': habitId,
          'date': date,
          'value': true,
        }),
    ]);
  }

  test('frequencies read safely and are named plainly', () {
    expect(
      HabitFrequency.fromJson({'times': 3, 'per_days': 7}).describe(),
      '3 times a week',
    );
    expect(
      HabitFrequency.fromJson({'times': 1, 'per_days': 2}).describe(),
      'Every other day',
    );
    expect(
      HabitFrequency.fromJson({'times': 1, 'per_days': 3}).describe(),
      'Every 3 days',
    );
    expect(
      HabitFrequency.fromJson({'times': 1, 'per_days': 7}).describe(),
      'Once a week',
    );
    expect(
      HabitFrequency.fromJson({'times': 2, 'per_days': 10}).describe(),
      '2 times every 10 days',
    );
    // Anything odd means every day, so a habit is never hidden by it.
    for (final odd in [
      null,
      'daily',
      {'times': 5, 'per_days': 3},
      {'times': 0, 'per_days': 7},
      {'times': 1.5, 'per_days': 7},
    ]) {
      expect(HabitFrequency.fromJson(odd), HabitFrequency.everyDay);
    }
  });

  test('every 3 days: done Monday, waits Tuesday and Wednesday', () {
    // 2026-11-16 is a Monday.
    final log = logWith({'times': 1, 'per_days': 3}, ['2026-11-16']);
    final habit = log.habits[habitId]!;

    expect(log.isDueOn(habit, '2026-11-16'), isTrue);
    expect(log.isDueOn(habit, '2026-11-17'), isFalse);
    expect(log.isDueOn(habit, '2026-11-18'), isFalse);
    expect(log.isDueOn(habit, '2026-11-19'), isTrue);
  });

  test('3 times a week: due until done three times in the week', () {
    final log = logWith(
      {'times': 3, 'per_days': 7},
      ['2026-11-16', '2026-11-17', '2026-11-18'],
    );
    final habit = log.habits[habitId]!;

    expect(log.isDueOn(habit, '2026-11-18'), isTrue);
    expect(log.isDueOn(habit, '2026-11-19'), isFalse);
    expect(log.isDueOn(habit, '2026-11-22'), isFalse);
    // A week after the first: due again.
    expect(log.isDueOn(habit, '2026-11-23'), isTrue);
  });

  test('waiting days keep a streak going; a missed due day ends it', () {
    // Every 3 days, kept up: Mon 16, Thu 19; then Sun 22 is due.
    final log = logWith(
      {'times': 1, 'per_days': 3},
      ['2026-11-16', '2026-11-19'],
    );
    final habit = log.habits[habitId]!;

    // On Sat 21: Mon to Sat, six days kept up (Sun 15 was due and not
    // done, which is where it starts).
    expect(log.streakOn(habit, parseDate('2026-11-21')!), 6);
    // On Mon 23: Sun 22 was due and not done, and Mon 23 is not over.
    expect(log.streakOn(habit, parseDate('2026-11-23')!), 0);
  });

  group('coversDay: the chain held around a ✗', () {
    /// Whether [frequency] covers a day, with the habit done on the days
    /// [done] away from it (-1 the day before, 1 the day after), and
    /// first marked [first] days away.
    bool covers(HabitFrequency frequency, List<int> done, {int? first}) =>
        frequency.coversDay(done.contains, firstOffset: first);

    const everyOtherDay = HabitFrequency(1, 2);
    const twiceAWeek = HabitFrequency(2, 7);

    test('every other day: a ✓ on each side keeps the chain', () {
      expect(covers(everyOtherDay, [-1, 1]), isTrue);
    });

    test('every other day: no ✓ after it breaks the chain', () {
      // ✓ Monday, ✗ Tuesday, ✗ Wednesday: neither is covered.
      expect(covers(everyOtherDay, [-1]), isFalse);
      expect(covers(everyOtherDay, [-2]), isFalse);
      // A ✓ on Thursday is too late: Tuesday–Wednesday had none.
      expect(covers(everyOtherDay, [-1, 2]), isFalse);
      expect(covers(everyOtherDay, [-2, 1]), isFalse);
    });

    test('twice a week: every week through the day has two ✓', () {
      // First marked Monday (-1); ✓ Monday and Thursday, then ✓ the
      // next Monday keeps Tuesday's week too.
      expect(covers(twiceAWeek, [-1, 2, 6], first: -1), isTrue);
      // Until that next ✓, the week from Tuesday has only one.
      expect(covers(twiceAWeek, [-1, 2], first: -1), isFalse);
    });

    test('weeks before the first mark are not checked', () {
      // The same ticks, but marking started long before with none.
      expect(covers(twiceAWeek, [-1, 2, 6], first: -30), isFalse);
      // A day before the first mark has nothing to keep.
      expect(covers(twiceAWeek, [2, 3, 6], first: 1), isFalse);
    });

    test('every day: other days never cover a ✗', () {
      expect(covers(HabitFrequency.everyDay, [-1, 1]), isFalse);
    });
  });
}
