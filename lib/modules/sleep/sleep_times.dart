// SPDX-License-Identifier: GPL-3.0-or-later

/// Turning clock times ("bed at 23:30, woke at 07:00") into exact
/// moments, and showing durations.
library;

import '../../core/clock_time.dart';
import '../../core/dates.dart';

export '../../core/clock_time.dart';

/// The start and end of one sleep, as local moments.
class SleepPeriod {
  /// Creates a period from [start] to [end].
  const SleepPeriod(this.start, this.end);

  /// When the sleep started (went to bed).
  final DateTime start;

  /// When it ended (woke up).
  final DateTime end;

  /// How long it lasted.
  Duration get duration => end.difference(start);
}

/// The moments of a nap that started on [day].
///
/// If the end is earlier on the clock than the start, the nap went past
/// midnight and ends the next day.
SleepPeriod napPeriod(DateTime day, ClockTime start, ClockTime end) {
  final endsNextDay = end.minutesSinceMidnight <= start.minutesSinceMidnight;
  final endDay = endsNextDay ? addDays(day, 1) : day;
  return SleepPeriod(_at(day, start), _at(endDay, end));
}

/// The local moment at [time] on [day].
DateTime _at(DateTime day, ClockTime time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

/// Checks that a sleep period makes sense. Returns null if it does, or a
/// message explaining what is wrong.
///
/// A sleep must last more than zero and less than 24 hours. Equal start
/// and end times would otherwise read as a full day.
String? checkSleepPeriod(SleepPeriod period) {
  final duration = period.duration;
  if (duration <= Duration.zero || duration >= const Duration(hours: 24)) {
    return 'The start and end times are the same. Please change one.';
  }
  return null;
}

/// The moment you woke up at [time] on [day].
DateTime wakeUpMoment(DateTime day, ClockTime time) => _at(day, time);

/// The moment you went to bed at [bed], ending [day].
///
/// Going to bed comes after waking up. So if [bed] is earlier on the
/// clock than [wokeUp] (for example bed at 01:00, woke up at 07:00), it
/// is after midnight, on the next calendar day. Without a wake-up time,
/// a bedtime before noon counts as after midnight.
DateTime bedtimeMoment(DateTime day, ClockTime bed, ClockTime? wokeUp) {
  final reference = wokeUp?.minutesSinceMidnight ?? 12 * 60;
  final isAfterMidnight = bed.minutesSinceMidnight < reference;
  return _at(isAfterMidnight ? addDays(day, 1) : day, bed);
}

/// Reads the clock time from a stored timestamp such as
/// `2026-11-17T23:30:00.000+09:00`. The text already holds the local
/// time where it was recorded, which is what the user lived, even if the
/// phone is in another time zone now.
ClockTime clockOfTimestamp(String timestamp) {
  final hour = int.parse(timestamp.substring(11, 13));
  final minute = int.parse(timestamp.substring(14, 16));
  return ClockTime(hour, minute);
}

/// The local date and time written in a stored timestamp such as
/// `2026-11-19T01:00:00.000+09:00`: here 19 November, 01:00. This is the
/// time as lived where it was recorded, whatever this phone's time zone.
DateTime localDateTimeOf(String timestamp) {
  final date = parseDate(timestamp.substring(0, 10))!;
  final clock = clockOfTimestamp(timestamp);
  return DateTime(date.year, date.month, date.day, clock.hour, clock.minute);
}

/// Checks a day's wake-up and bedtime. Returns null if they make sense,
/// or a message explaining what is wrong. Either may be missing.
String? checkDayTimes(DateTime? wokeUp, DateTime? wentToBed) {
  if (wokeUp == null || wentToBed == null) {
    return null;
  }
  if (!wentToBed.isAfter(wokeUp)) {
    return 'Went to bed must be after waking up.';
  }
  if (wentToBed.difference(wokeUp) >= const Duration(hours: 24)) {
    return 'Went to bed must be within a day of waking up.';
  }
  return null;
}
