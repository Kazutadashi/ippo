// SPDX-License-Identifier: GPL-3.0-or-later

/// A moment of a day's sleep: when you woke up, or when you went to bed.
library;

import '../../core/dates.dart';
import '../../core/events/things.dart';
import '../../core/events/timestamp.dart';
import 'sleep_times.dart';

/// The two kinds of moment. [eventName] is used in the event types
/// (`woke_up_recorded`, `went_to_bed_changed`, ...) and must never
/// change.
enum MomentKind {
  /// Woke up: the start of a day.
  wokeUp('woke_up', 'Woke up'),

  /// Went to bed: the end of a day, possibly after midnight.
  wentToBed('went_to_bed', 'Went to bed');

  const MomentKind(this.eventName, this.label);

  /// The name used in event types.
  final String eventName;

  /// The name on screen.
  final String label;
}

/// When you woke up or went to bed, and the day it belongs to.
///
/// A "day" runs from waking up to going to bed. Going to bed at 01:00
/// still belongs to the day before, because you had not slept yet. See
/// "Module: sleep" in `docs/data-format.md`.
class SleepMoment {
  /// Creates a moment.
  const SleepMoment({
    required this.id,
    required this.kind,
    required this.date,
    required this.at,
    required this.atUtc,
    required this.isDeleted,
    required this.oldNightId,
  });

  /// Reads a moment from its collected events. Returns null if the data
  /// is not valid.
  static SleepMoment? fromRecord(ThingRecord record, MomentKind kind) {
    final date = record.fields['date'];
    final at = record.fields['at'];
    if (date is! String || !isValidDate(date) || at is! String) {
      return null;
    }
    final atUtc = parseTimestamp(at);
    if (atUtc == null) {
      return null;
    }
    return SleepMoment(
      id: record.id,
      kind: kind,
      date: date,
      at: at,
      atUtc: atUtc,
      isDeleted: record.isDeleted,
      oldNightId: null,
    );
  }

  /// The moment's id: the id of the event that recorded it.
  final String id;

  /// Woke up or went to bed.
  final MomentKind kind;

  /// The day it belongs to, `YYYY-MM-DD`.
  final String date;

  /// The moment, as stored, with its time zone offset.
  final String at;

  /// The same moment in UTC.
  final DateTime atUtc;

  /// Whether it was deleted.
  final bool isDeleted;

  /// If this moment comes from a whole night saved by an older version
  /// of Ippo (one record from bedtime to wake-up), that night's id.
  /// Otherwise null.
  final String? oldNightId;

  /// The time on the clock, as it was where the user was.
  ClockTime get clock => clockOfTimestamp(at);

  /// The calendar date of the moment, `YYYY-MM-DD`. For a bedtime after
  /// midnight, this is the day after [date].
  String get calendarDate => at.substring(0, 10);

  /// Whether the moment is on a later calendar day than the day it
  /// belongs to (a bedtime after midnight).
  bool get isAfterMidnight => calendarDate != date;
}
