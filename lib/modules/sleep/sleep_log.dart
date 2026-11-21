// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's current state, worked out from the event log.
library;

import '../../core/dates.dart';
import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'nap.dart';
import 'sleep_moment.dart';

/// The module's name in event files. Never change it.
const String sleepModuleName = 'sleep';

/// All wake-ups, bedtimes and naps, with every change applied.
///
/// A day runs from waking up to going to bed. The sleep before a day is
/// the time from the previous day's bedtime to that day's wake-up.
class SleepLog {
  /// Creates a log. Normal code uses [SleepLog.fromEvents].
  SleepLog({
    required this.moments,
    required this.naps,
    required this.invalidCount,
  });

  /// The current state for [appState], worked out once per change of
  /// the data and shared by every screen (see `AppState.derived`).
  static SleepLog of(AppState appState) =>
      appState.derived('sleep_log', SleepLog.fromEvents);

  /// Builds the log from the event log's events (oldest first).
  factory SleepLog.fromEvents(List<Event> events) {
    var invalidCount = 0;

    final moments = <SleepMoment>[];
    for (final kind in MomentKind.values) {
      final records = collectThings(
        events,
        module: sleepModuleName,
        createdType: '${kind.eventName}_recorded',
        thingName: kind.eventName,
      );
      for (final record in records.values) {
        final moment = SleepMoment.fromRecord(record, kind);
        if (moment == null) {
          invalidCount++;
        } else {
          moments.add(moment);
        }
      }
    }

    final naps = <Nap>[];
    final napRecords = collectThings(
      events,
      module: sleepModuleName,
      createdType: 'nap_recorded',
      thingName: 'nap',
    );
    for (final record in napRecords.values) {
      final nap = Nap.fromRecord(record);
      if (nap == null) {
        invalidCount++;
      } else {
        naps.add(nap);
      }
    }

    return SleepLog(moments: moments, naps: naps, invalidCount: invalidCount);
  }

  /// Every wake-up and bedtime recorded directly, including deleted ones,
  /// in the order they were made.
  final List<SleepMoment> moments;

  /// Every nap, including deleted ones, in the order they were made.
  final List<Nap> naps;

  /// How many records were skipped because their data was not valid.
  final int invalidCount;

  /// When you woke up on [date] (`YYYY-MM-DD`), or null if not known.
  SleepMoment? wakeUpOn(String date) => _momentOn(date, MomentKind.wokeUp);

  /// When you went to bed at the end of [date], or null if not known.
  /// It may be after midnight, on the next calendar day.
  SleepMoment? bedtimeOf(String date) => _momentOn(date, MomentKind.wentToBed);

  /// How long you slept before [date]: from the previous day's bedtime to
  /// this day's wake-up. Null if either is not known.
  Duration? sleepBefore(String date) {
    final previousDay = formatDate(addDays(parseDate(date)!, -1));
    final bedtime = bedtimeOf(previousDay);
    final wakeUp = wakeUpOn(date);
    if (bedtime == null || wakeUp == null) {
      return null;
    }
    final duration = wakeUp.atUtc.difference(bedtime.atUtc);
    return duration.isNegative ? null : duration;
  }

  /// The naps on [date], earliest first.
  List<Nap> napsOn(String date) {
    return naps.where((nap) => nap.date == date && !nap.isDeleted).toList()
      ..sort(
        (first, second) => first.startedAtUtc.compareTo(second.startedAtUtc),
      );
  }

  /// The most recent moment of [kind], or null. Its clock time is a good
  /// first guess for the next one.
  SleepMoment? latest(MomentKind kind) {
    SleepMoment? found;
    for (final moment in moments) {
      if (moment.kind == kind && !moment.isDeleted) {
        found = moment;
      }
    }
    return found;
  }

  /// The average sleep a night over the 7 nights before [day], counting
  /// only nights logged; null without any. The Home tile and the Sleep
  /// tab both show it.
  Duration? averageSleepBefore(DateTime day) {
    var total = Duration.zero;
    var nights = 0;
    for (var back = 1; back <= 7; back++) {
      final slept = sleepBefore(formatDate(addDays(day, -back)));
      if (slept != null) {
        total += slept;
        nights++;
      }
    }
    return nights == 0 ? null : total ~/ nights;
  }

  /// The latest moment of [kind] recorded for [date], if any. If several
  /// were recorded, the last one counts.
  SleepMoment? _momentOn(String date, MomentKind kind) =>
      _latestMoments['${kind.name} $date'];

  /// The last moment of each kind on each day that is not deleted, by
  /// `"<kind> <date>"`. Built once, the first time it is needed, so the
  /// screens that look at many nights do not search every moment each
  /// time.
  late final Map<String, SleepMoment> _latestMoments = {
    for (final moment in moments)
      if (!moment.isDeleted) '${moment.kind.name} ${moment.date}': moment,
  };
}
