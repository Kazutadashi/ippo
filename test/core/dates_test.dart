// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the clock style and the day boundary in `dates.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/clock_time.dart';
import 'package:ippo/core/dates.dart';

void main() {
  tearDown(() => showTimesIn24Hours = true);

  test('times can be shown on a 24-hour or a 12-hour clock', () {
    expect(formatClock(19, 30), '19:30');
    expect(formatClock(7, 5), '07:05');

    showTimesIn24Hours = false;
    expect(formatClock(19, 30), '7:30 pm');
    expect(formatClock(0, 15), '12:15 am');
    expect(formatClock(12, 0), '12:00 pm');
    expect(showSavedTime('23:40'), '11:40 pm');
    expect(const ClockTime(6, 45).shown, '6:45 am');
  });

  test('the clock style never changes how times are saved', () {
    showTimesIn24Hours = false;
    expect(const ClockTime(19, 30).toString(), '19:30');
    expect(formatTimeOfDay(DateTime(2026, 11, 19, 19, 30)), '19:30');
  });

  test('a day lasts until 05:00 the next morning', () {
    final tuesday = DateTime(2026, 11, 17);
    expect(currentDay(DateTime(2026, 11, 18, 1, 30)), tuesday);
    expect(currentDay(DateTime(2026, 11, 18, 5)), DateTime(2026, 11, 18));
    expect(momentOnDay(tuesday, '01:05'), DateTime(2026, 11, 18, 1, 5));
    expect(momentOnDay(tuesday, '23:30'), DateTime(2026, 11, 17, 23, 30));
  });
}
