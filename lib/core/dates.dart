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

/// The hour at which a new day starts. Before it you are still in the
/// day before: a snack at 01:00, or going to bed at 02:00, counts for
/// the evening you were still awake in. Every module uses this same
/// boundary, so "today" means the same thing on every screen.
const int dayStartHour = 5;

/// The day you are in at [now]: its calendar day, or the day before if
/// it is earlier than [dayStartHour]. Returned at local midnight.
DateTime currentDay(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return now.hour < dayStartHour ? addDays(day, -1) : day;
}

/// The day you are in right now (see [currentDay]).
DateTime today() => currentDay(DateTime.now());

/// The local moment at [time] (`HH:MM`) on [day], where [day] runs from
/// [dayStartHour] to [dayStartHour] the next morning: 01:05 on Monday is
/// early on Tuesday's calendar day. Returns null if [time] is not valid.
DateTime? momentOnDay(DateTime day, String time) {
  if (!isValidTimeOfDay(time)) {
    return null;
  }
  final hour = int.parse(time.substring(0, 2));
  final minute = int.parse(time.substring(3, 5));
  final calendarDay = hour < dayStartHour ? addDays(day, 1) : day;
  return DateTime(
    calendarDay.year,
    calendarDay.month,
    calendarDay.day,
    hour,
    minute,
  );
}

/// Whether times are shown on a 24-hour clock ("19:30") rather than a
/// 12-hour one ("7:30 pm").
///
/// The user chooses this in Settings; the app sets it when it starts and
/// whenever the setting changes. It only changes how times are *shown*:
/// times are always saved as 24-hour `HH:MM`, so the data never depends
/// on it.
bool showTimesIn24Hours = true;

/// Shows a clock time in the user's chosen style: `19:30`, or `7:30 pm`.
String formatClock(int hour, int minute) {
  final minutes = _digits(minute, 2);
  if (showTimesIn24Hours) {
    return '${_digits(hour, 2)}:$minutes';
  }
  final hourOn12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hourOn12:$minutes ${hour < 12 ? 'am' : 'pm'}';
}

/// Shows the clock time of [moment] in the user's chosen style. (For
/// saving, use [formatTimeOfDay], which is always `HH:MM`.)
String showTimeOfDay(DateTime moment) =>
    formatClock(moment.hour, moment.minute);

/// Shows a saved `HH:MM` time in the user's chosen style. Text that is
/// not such a time is shown as it is.
String showSavedTime(String time) {
  if (!isValidTimeOfDay(time)) {
    return time;
  }
  return formatClock(
    int.parse(time.substring(0, 2)),
    int.parse(time.substring(3, 5)),
  );
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
  if (elapsed.inMinutes < 60) {
    return '${elapsed.inMinutes} min ago';
  }
  // From an hour on, whole hours are enough for a glance: "8 h ago",
  // not "7 h 58 min ago".
  return '${(elapsed.inMinutes / 60).round()} h ago';
}

/// Writes [number] with leading zeros up to [width] digits.
String _digits(int number, int width) => number.toString().padLeft(width, '0');

/// A moment as this device's local day and time, the way the app writes
/// both everywhere: `Thu 19 Nov, 11:58 pm` (or `23:58` with the 24-hour
/// clock).
String formatDateAndTime(DateTime moment) {
  final local = moment.toLocal();
  return '${formatShortDate(local)}, ${showTimeOfDay(local)}';
}

/// A date (`YYYY-MM-DD`) as on screen, such as "Mon 16 Nov"; the text as
/// it is if it is not a date.
String describeDayOf(String date) {
  final day = parseDate(date);
  return day == null ? date : formatShortDate(day);
}

/// Writes a day for the heading, for example `Tuesday, 18 Nov`. The
/// month is short, so the date fits on one line beside the day bar.
String describeToday(DateTime day) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';
}
