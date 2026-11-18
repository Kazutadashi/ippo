// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for turning clock times into sleep periods.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';

void main() {
  final monday = DateTime(2026, 11, 16);

  group('napPeriod', () {
    test('a normal afternoon nap', () {
      final nap = napPeriod(
        monday,
        const ClockTime(14, 0),
        const ClockTime(14, 45),
      );
      expect(nap.start, DateTime(2026, 11, 16, 14, 0));
      expect(nap.duration, const Duration(minutes: 45));
    });

    test('a nap past midnight ends the next day', () {
      final nap = napPeriod(
        monday,
        const ClockTime(23, 30),
        const ClockTime(0, 15),
      );
      expect(nap.end, DateTime(2026, 11, 17, 0, 15));
      expect(nap.duration, const Duration(minutes: 45));
    });
  });

  test('equal start and end times are refused', () {
    final nap = napPeriod(
      monday,
      const ClockTime(14, 0),
      const ClockTime(14, 0),
    );
    expect(checkSleepPeriod(nap), isNotNull);
  });

  test('a normal period is accepted', () {
    final nap = napPeriod(
      monday,
      const ClockTime(23, 0),
      const ClockTime(7, 0),
    );
    expect(checkSleepPeriod(nap), isNull);
  });

  group('bedtimeMoment', () {
    test('earlier on the clock than waking up means after midnight', () {
      expect(
        bedtimeMoment(monday, const ClockTime(1, 0), const ClockTime(7, 0)),
        DateTime(2026, 11, 17, 1, 0),
      );
    });

    test('later on the clock than waking up is the same day', () {
      expect(
        bedtimeMoment(monday, const ClockTime(23, 0), const ClockTime(7, 0)),
        DateTime(2026, 11, 16, 23, 0),
      );
    });

    test('without a wake-up, before noon means after midnight', () {
      expect(
        bedtimeMoment(monday, const ClockTime(2, 0), null),
        DateTime(2026, 11, 17, 2, 0),
      );
      expect(
        bedtimeMoment(monday, const ClockTime(22, 0), null),
        DateTime(2026, 11, 16, 22, 0),
      );
    });
  });

  test('before 05:00 the sleep day is still the day before', () {
    expect(currentSleepDay(DateTime(2026, 11, 17, 1, 30)), monday);
    expect(currentSleepDay(DateTime(2026, 11, 17, 4, 59)), monday);
    expect(
      currentSleepDay(DateTime(2026, 11, 17, 5, 0)),
      DateTime(2026, 11, 17),
    );
  });

  group('checkDayTimes', () {
    final wokeUp = DateTime(2026, 11, 16, 7);

    test('a bedtime after waking up, within a day, is fine', () {
      expect(checkDayTimes(wokeUp, DateTime(2026, 11, 17, 1)), isNull);
      expect(checkDayTimes(wokeUp, null), isNull);
      expect(checkDayTimes(null, DateTime(2026, 11, 17, 1)), isNull);
    });

    test('a bedtime before waking up is refused', () {
      expect(checkDayTimes(wokeUp, DateTime(2026, 11, 16, 6)), isNotNull);
      expect(checkDayTimes(wokeUp, wokeUp), isNotNull);
    });

    test('a bedtime more than a day later is refused', () {
      expect(checkDayTimes(wokeUp, DateTime(2026, 11, 17, 8)), isNotNull);
    });
  });

  test('localDateTimeOf reads the time as lived', () {
    expect(
      localDateTimeOf('2026-11-17T01:30:00.000+09:00'),
      DateTime(2026, 11, 17, 1, 30),
    );
  });

  test('formatShortDate', () {
    expect(formatShortDate(DateTime(2026, 11, 19)), 'Thu 19 Nov');
  });

  test('formatTimeAgo', () {
    expect(formatTimeAgo(const Duration(seconds: 30)), 'Just now');
    expect(formatTimeAgo(const Duration(minutes: 25)), '25 min ago');
    expect(formatTimeAgo(const Duration(hours: 3)), '3 h ago');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(hours: 7, minutes: 30)), '7 h 30 min');
    expect(formatDuration(const Duration(hours: 8)), '8 h');
    expect(formatDuration(const Duration(minutes: 45)), '45 min');
  });

  test('clock times are written as HH:MM', () {
    expect(const ClockTime(7, 5).toString(), '07:05');
    expect(const ClockTime(23, 30).toString(), '23:30');
  });
}
