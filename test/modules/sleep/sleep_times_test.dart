// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for turning clock times into sleep periods.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';

void main() {
  final monday = DateTime(2026, 11, 16);

  group('nightPeriod', () {
    test('bed before midnight means the evening before', () {
      final night = nightPeriod(
        monday,
        const ClockTime(23, 30),
        const ClockTime(7, 0),
      );
      expect(night.start, DateTime(2026, 11, 15, 23, 30));
      expect(night.end, DateTime(2026, 11, 16, 7, 0));
      expect(night.duration, const Duration(hours: 7, minutes: 30));
    });

    test('bed after midnight means the same day as waking', () {
      final night = nightPeriod(
        monday,
        const ClockTime(0, 30),
        const ClockTime(7, 0),
      );
      expect(night.start, DateTime(2026, 11, 16, 0, 30));
      expect(night.duration, const Duration(hours: 6, minutes: 30));
    });

    test('works across a month boundary', () {
      final night = nightPeriod(
        DateTime(2026, 12, 1),
        const ClockTime(22, 0),
        const ClockTime(6, 0),
      );
      expect(night.start, DateTime(2026, 11, 30, 22, 0));
    });
  });

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
    final night = nightPeriod(
      monday,
      const ClockTime(7, 0),
      const ClockTime(7, 0),
    );
    expect(checkSleepPeriod(night), isNotNull);
    final nap = napPeriod(
      monday,
      const ClockTime(14, 0),
      const ClockTime(14, 0),
    );
    expect(checkSleepPeriod(nap), isNotNull);
  });

  test('a normal period is accepted', () {
    final night = nightPeriod(
      monday,
      const ClockTime(23, 0),
      const ClockTime(7, 0),
    );
    expect(checkSleepPeriod(night), isNull);
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
