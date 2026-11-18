// SPDX-License-Identifier: GPL-3.0-or-later

/// Writing and reading timestamps.
///
/// A timestamp is an exact moment with the local time zone offset, for
/// example `2026-11-17T21:04:11.123+09:00`. See "Timestamps" in
/// `docs/data-format.md`.
library;

/// Matches the shape of an RFC 3339 timestamp that has a time zone.
///
/// Readers accept any number of fraction digits and `Z` for UTC, so data
/// written by other tools still loads. Writers always use the exact form
/// produced by [formatTimestamp].
///
/// The groups are: 1 year, 2 month, 3 day, 4 hour, 5 minute, 6 second,
/// 7 fraction, 8 the whole time zone, 9 offset hours, 10 offset minutes.
final RegExp _timestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?'
  r'(Z|[+-](\d{2}):(\d{2}))$',
);

/// Writes [moment] in the device's local time, with its offset.
///
/// Example: `2026-11-17T21:04:11.123+09:00`.
String formatTimestamp(DateTime moment) {
  final localMoment = moment.toLocal();
  return formatTimestampWithOffset(moment, localMoment.timeZoneOffset);
}

/// Writes [moment] as it looks in a time zone [offset] from UTC.
///
/// [formatTimestamp] is what normal code uses. This version exists so
/// tests do not depend on the time zone of the computer running them.
String formatTimestampWithOffset(DateTime moment, Duration offset) {
  // Shift the moment by the offset, then print its UTC fields: those are
  // the local clock readings in that time zone.
  final wallClock = moment.toUtc().add(offset);
  final date =
      '${_digits(wallClock.year, 4)}-${_digits(wallClock.month, 2)}-'
      '${_digits(wallClock.day, 2)}';
  final time =
      '${_digits(wallClock.hour, 2)}:${_digits(wallClock.minute, 2)}:'
      '${_digits(wallClock.second, 2)}.${_digits(wallClock.millisecond, 3)}';
  return '${date}T$time${_formatOffset(offset)}';
}

/// Reads a timestamp. Returns the exact moment in UTC, or null if [text]
/// is not a timestamp with a time zone.
///
/// A timestamp without a time zone is refused on purpose: it could mean
/// different moments on different devices.
///
/// Impossible values, such as month 13 or 25 o'clock, are refused too.
/// (Dart's own parser would quietly turn them into some other date.)
DateTime? parseTimestamp(String text) {
  final match = _timestampPattern.firstMatch(text);
  if (match == null || !_hasValidParts(match)) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}

/// Checks that each part of a matched timestamp is in its normal range.
bool _hasValidParts(RegExpMatch match) {
  int part(int group) => int.parse(match.group(group) ?? '0');

  final year = part(1);
  final month = part(2);
  final day = part(3);
  // Building the date and comparing catches days such as 31 April:
  // Dart would roll those over into the next month.
  final date = DateTime.utc(year, month, day);
  final isRealDate =
      month >= 1 && date.year == year && date.month == month && date.day == day;

  final isRealTime = part(4) <= 23 && part(5) <= 59 && part(6) <= 59;
  final isRealOffset = part(9) <= 23 && part(10) <= 59;
  return isRealDate && isRealTime && isRealOffset;
}

/// Writes an offset such as `+09:00`, `-04:30` or `+00:00`.
String _formatOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final totalMinutes = offset.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '$sign${_digits(hours, 2)}:${_digits(minutes, 2)}';
}

/// Writes [number] with leading zeros up to [width] digits.
String _digits(int number, int width) => number.toString().padLeft(width, '0');
