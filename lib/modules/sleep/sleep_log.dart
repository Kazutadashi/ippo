// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's current state, worked out from the event log.
library;

import '../../core/dates.dart';
import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'sleep_episode.dart';
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
    required this.episodes,
    required this.invalidCount,
  });

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

    final episodes = <SleepEpisode>[];
    final episodeRecords = collectThings(
      events,
      module: sleepModuleName,
      createdType: 'sleep_recorded',
      thingName: 'sleep',
    );
    for (final record in episodeRecords.values) {
      final episode = SleepEpisode.fromRecord(record);
      if (episode == null) {
        invalidCount++;
      } else {
        episodes.add(episode);
      }
    }

    return SleepLog(
      moments: moments,
      episodes: episodes,
      invalidCount: invalidCount,
    );
  }

  /// Every wake-up and bedtime recorded directly, including deleted ones,
  /// in the order they were made.
  final List<SleepMoment> moments;

  /// Every nap, and every whole night saved by older versions, including
  /// deleted ones, in the order they were made.
  final List<SleepEpisode> episodes;

  /// How many records were skipped because their data was not valid.
  final int invalidCount;

  /// When you woke up on [date] (`YYYY-MM-DD`), or null if not known.
  SleepMoment? wakeUpOn(String date) =>
      _momentOn(date, MomentKind.wokeUp) ?? _fromOldNightEndingOn(date);

  /// When you went to bed at the end of [date], or null if not known.
  /// It may be after midnight, on the next calendar day.
  SleepMoment? bedtimeOf(String date) =>
      _momentOn(date, MomentKind.wentToBed) ?? _fromOldNightStartingAfter(date);

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
  List<SleepEpisode> napsOn(String date) {
    return episodes
        .where(
          (episode) =>
              episode.date == date &&
              episode.kind == SleepKind.nap &&
              !episode.isDeleted,
        )
        .toList()
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

  /// The latest moment of [kind] recorded for [date], if any. If several
  /// were recorded, the last one counts.
  SleepMoment? _momentOn(String date, MomentKind kind) {
    SleepMoment? found;
    for (final moment in moments) {
      if (moment.kind == kind && moment.date == date && !moment.isDeleted) {
        found = moment;
      }
    }
    return found;
  }

  /// The wake-up from an older, whole-night record ending on [date].
  SleepMoment? _fromOldNightEndingOn(String date) {
    final night = _oldNightFor(date);
    if (night == null) {
      return null;
    }
    return SleepMoment(
      id: night.id,
      kind: MomentKind.wokeUp,
      date: date,
      at: night.endedAt,
      atUtc: night.endedAtUtc,
      isDeleted: false,
      oldNightId: night.id,
    );
  }

  /// The bedtime from an older, whole-night record: that night started at
  /// the end of [date] and ended on the next day.
  SleepMoment? _fromOldNightStartingAfter(String date) {
    final nextDay = formatDate(addDays(parseDate(date)!, 1));
    final night = _oldNightFor(nextDay);
    if (night == null) {
      return null;
    }
    return SleepMoment(
      id: night.id,
      kind: MomentKind.wentToBed,
      date: date,
      at: night.startedAt,
      atUtc: night.startedAtUtc,
      isDeleted: false,
      oldNightId: night.id,
    );
  }

  /// The latest whole night, saved by an older version, that ended on
  /// [wakeDate].
  SleepEpisode? _oldNightFor(String wakeDate) {
    SleepEpisode? found;
    for (final episode in episodes) {
      if (episode.kind == SleepKind.night &&
          episode.date == wakeDate &&
          !episode.isDeleted) {
        found = episode;
      }
    }
    return found;
  }
}
