// SPDX-License-Identifier: GPL-3.0-or-later

/// One nap during the day.
library;

import '../../core/dates.dart';
import '../../core/events/things.dart';
import '../../core/events/timestamp.dart';
import 'sleep_times.dart';

/// One nap. Created by `nap_recorded`; see "Module: sleep" in
/// `docs/data-format.md`.
class Nap {
  /// Creates a nap.
  const Nap({
    required this.id,
    required this.date,
    required this.startedAt,
    required this.endedAt,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.isDeleted,
  });

  /// Reads a nap from its collected events. Returns null if the data is
  /// not valid, including if it ends before it starts.
  static Nap? fromRecord(ThingRecord record) {
    final fields = record.fields;
    final date = fields['date'];
    final startedAt = fields['started_at'];
    final endedAt = fields['ended_at'];
    if (date is! String || !isValidDate(date)) {
      return null;
    }
    if (startedAt is! String || endedAt is! String) {
      return null;
    }
    final startedAtUtc = parseTimestamp(startedAt);
    final endedAtUtc = parseTimestamp(endedAt);
    if (startedAtUtc == null ||
        endedAtUtc == null ||
        !endedAtUtc.isAfter(startedAtUtc)) {
      return null;
    }
    return Nap(
      id: record.id,
      date: date,
      startedAt: startedAt,
      endedAt: endedAt,
      startedAtUtc: startedAtUtc,
      endedAtUtc: endedAtUtc,
      isDeleted: record.isDeleted,
    );
  }

  /// The nap's id.
  final String id;

  /// The day of the nap, `YYYY-MM-DD`.
  final String date;

  /// When the nap started, as stored, with its time zone offset.
  final String startedAt;

  /// When it ended, as stored, with its time zone offset.
  final String endedAt;

  /// The same moment as [startedAt], in UTC.
  final DateTime startedAtUtc;

  /// The same moment as [endedAt], in UTC.
  final DateTime endedAtUtc;

  /// Whether the nap was deleted.
  final bool isDeleted;

  /// How long the nap lasted.
  Duration get duration => endedAtUtc.difference(startedAtUtc);

  /// The start on the clock, as it was where the user was.
  ClockTime get startClock => clockOfTimestamp(startedAt);

  /// The end on the clock, as it was where the user was.
  ClockTime get endClock => clockOfTimestamp(endedAt);
}
