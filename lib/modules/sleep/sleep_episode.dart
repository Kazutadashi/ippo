// SPDX-License-Identifier: GPL-3.0-or-later

/// One sleep: a night or a nap.
library;

import '../../core/dates.dart';
import '../../core/events/things.dart';
import '../../core/events/timestamp.dart';
import 'sleep_times.dart';

/// The kinds of sleep. The names are stored in the data and must never
/// change.
enum SleepKind {
  /// The main sleep of the night.
  night,

  /// A nap during the day.
  nap;

  /// Finds the kind stored as [name], or null if there is none.
  static SleepKind? fromName(Object? name) {
    for (final kind in SleepKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }
}

/// One nap (or, from older versions, a whole night). Created by
/// `sleep_recorded`; see "Module: sleep" in `docs/data-format.md`.
class SleepEpisode {
  /// Creates a sleep episode.
  const SleepEpisode({
    required this.id,
    required this.date,
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.isDeleted,
  });

  /// Reads an episode from its collected events. Returns null if the
  /// data is not valid, including if it ends before it starts.
  static SleepEpisode? fromRecord(ThingRecord record) {
    final fields = record.fields;
    final date = fields['date'];
    final kind = SleepKind.fromName(fields['kind']);
    final startedAt = fields['started_at'];
    final endedAt = fields['ended_at'];
    if (date is! String || !isValidDate(date) || kind == null) {
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
    return SleepEpisode(
      id: record.id,
      date: date,
      kind: kind,
      startedAt: startedAt,
      endedAt: endedAt,
      startedAtUtc: startedAtUtc,
      endedAtUtc: endedAtUtc,
      isDeleted: record.isDeleted,
    );
  }

  /// The episode's id.
  final String id;

  /// The day it counts for, `YYYY-MM-DD`: the wake-up day for a night.
  final String date;

  /// A night or a nap.
  final SleepKind kind;

  /// When the sleep started, as stored, with its time zone offset.
  final String startedAt;

  /// When it ended, as stored, with its time zone offset.
  final String endedAt;

  /// The same moment as [startedAt], in UTC.
  final DateTime startedAtUtc;

  /// The same moment as [endedAt], in UTC.
  final DateTime endedAtUtc;

  /// Whether the episode was deleted.
  final bool isDeleted;

  /// How long the sleep lasted.
  Duration get duration => endedAtUtc.difference(startedAtUtc);

  /// The bedtime on the clock, as it was where the user slept.
  ClockTime get startClock => clockOfTimestamp(startedAt);

  /// The wake-up time on the clock, as it was where the user slept.
  ClockTime get endClock => clockOfTimestamp(endedAt);
}
