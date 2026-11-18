// SPDX-License-Identifier: GPL-3.0-or-later

/// Writing and reading calendar dates (`YYYY-MM-DD`) and times of day
/// (`HH:MM`), as described in "Value types" in `docs/data-format.md`.
library;

/// Matches a date such as `2026-11-17`.
final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Matches a time of day such as `07:30`.
final RegExp _timeOfDayPattern = RegExp(r'^(\d{2}):(\d{2})$');

/// Writes the calendar day of [day] as `YYYY-MM-DD`. The time part of
/// [day] is ignored.
String formatDate(DateTime day) {
  return '${_digits(day.year, 4)}-${_digits(day.month, 2)}-'
      '${_digits(day.day, 2)}';
}

/// Reads a date written by [formatDate]. Returns a local [DateTime] at
/// midnight, or null if [text] is not a real date.
DateTime? parseDate(String text) {
  final match = _datePattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime quietly rolls 31 April over into May; refuse such dates.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Returns true if [text] is a real date written as `YYYY-MM-DD`.
bool isValidDate(String text) => parseDate(text) != null;

/// Writes the clock time of [moment] as `HH:MM`.
String formatTimeOfDay(DateTime moment) {
  return '${_digits(moment.hour, 2)}:${_digits(moment.minute, 2)}';
}

/// Returns true if [text] is a real time of day written as `HH:MM`.
bool isValidTimeOfDay(String text) {
  final match = _timeOfDayPattern.firstMatch(text);
  if (match == null) {
    return false;
  }
  return int.parse(match.group(1)!) <= 23 && int.parse(match.group(2)!) <= 59;
}

/// Returns the day before or after [day]: [days] can be negative.
///
/// Uses calendar arithmetic rather than adding 24 hours, because days
/// around a daylight saving change are 23 or 25 hours long.
DateTime addDays(DateTime day, int days) {
  return DateTime(day.year, day.month, day.day + days);
}

/// Writes a day briefly, for example `Thu 19 Nov`.
String formatShortDate(DateTime day) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
}

/// Writes a duration as hours and minutes, for example `7 h 30 min`,
/// `45 min` or `8 h`.
String formatDuration(Duration duration) {
  final hours = duration.inMinutes ~/ 60;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) {
    return '$minutes min';
  }
  if (minutes == 0) {
    return '$hours h';
  }
  return '$hours h $minutes min';
}

/// Writes how long ago something was, for example `3 h ago`, `25 min
/// ago`, or `Just now` for less than a minute.
String formatTimeAgo(Duration elapsed) {
  if (elapsed.inMinutes < 1) {
    return 'Just now';
  }
  return '${formatDuration(elapsed)} ago';
}

/// Writes [number] with leading zeros up to [width] digits.
String _digits(int number, int width) => number.toString().padLeft(width, '0');
