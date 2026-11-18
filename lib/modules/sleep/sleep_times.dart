// SPDX-License-Identifier: GPL-3.0-or-later

/// Turning clock times ("bed at 23:30, woke at 07:00") into exact
/// moments, and showing durations.
library;

import '../../core/dates.dart';

/// A time on the clock, such as 23:30, without a date.
class ClockTime {
  /// Creates a clock time. [hour] is 0 to 23, [minute] 0 to 59.
  const ClockTime(this.hour, this.minute);

  /// The hour, 0 to 23.
  final int hour;

  /// The minute, 0 to 59.
  final int minute;

  /// Minutes since midnight, for comparing clock times.
  int get minutesSinceMidnight => hour * 60 + minute;

  /// Writes the time as `HH:MM`.
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => minutesSinceMidnight;
}

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

/// The moments of a night's sleep that ended on [wakeDay].
///
/// The wake-up is on [wakeDay]. The bedtime is the evening before if it
/// is later on the clock than the wake-up (bed 23:30, woke 07:00), and
/// on [wakeDay] itself otherwise (bed 00:30, woke 07:00: both after
/// midnight).
SleepPeriod nightPeriod(DateTime wakeDay, ClockTime bed, ClockTime woke) {
  final end = _at(wakeDay, woke);
  final bedIsTheEveningBefore =
      bed.minutesSinceMidnight >= woke.minutesSinceMidnight;
  final bedDay = bedIsTheEveningBefore ? addDays(wakeDay, -1) : wakeDay;
  return SleepPeriod(_at(bedDay, bed), end);
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

/// The hour at which a new day starts for sleep. Before it, you are
/// still in the day before (up late, not yet asleep).
const int sleepDayStartHour = 5;

/// The day you are in right now, for sleep: today, or yesterday if it is
/// before [sleepDayStartHour] in the morning.
DateTime currentSleepDay(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return now.hour < sleepDayStartHour ? addDays(day, -1) : day;
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
