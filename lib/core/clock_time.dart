// SPDX-License-Identifier: GPL-3.0-or-later

/// A time on the clock without a date, such as 23:30.
library;

import 'dates.dart';

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

  /// The time as the user likes to see it: `19:30` or `7:30 pm`.
  String get shown => formatClock(hour, minute);

  /// Writes the time as `HH:MM`, the form it is saved in.
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => minutesSinceMidnight;
}
