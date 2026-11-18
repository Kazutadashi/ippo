// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's current state, worked out from the event log.
library;

import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'sleep_episode.dart';

/// The module's name in event files. Never change it.
const String sleepModuleName = 'sleep';

/// All nights and naps, with every change applied.
class SleepLog {
  /// Creates a log. Normal code uses [SleepLog.fromEvents].
  SleepLog({required this.episodes, required this.invalidCount});

  /// Builds the log from the event log's events (oldest first).
  factory SleepLog.fromEvents(List<Event> events) {
    final records = collectThings(
      events,
      module: sleepModuleName,
      createdType: 'sleep_recorded',
      thingName: 'sleep',
    );
    var invalidCount = 0;
    final episodes = <SleepEpisode>[];
    for (final record in records.values) {
      final episode = SleepEpisode.fromRecord(record);
      if (episode == null) {
        invalidCount++;
      } else {
        episodes.add(episode);
      }
    }
    return SleepLog(episodes: episodes, invalidCount: invalidCount);
  }

  /// Every episode, including deleted ones, in the order they were made.
  final List<SleepEpisode> episodes;

  /// How many episodes were skipped because their data was not valid.
  final int invalidCount;

  /// The night that ended on [date] (`YYYY-MM-DD`), or null if none.
  ///
  /// If several were logged for one day, the latest one counts.
  SleepEpisode? nightOn(String date) {
    SleepEpisode? found;
    for (final episode in _activeOn(date)) {
      if (episode.kind == SleepKind.night) {
        found = episode;
      }
    }
    return found;
  }

  /// The naps on [date], earliest first.
  List<SleepEpisode> napsOn(String date) {
    return _activeOn(date)
        .where((episode) => episode.kind == SleepKind.nap)
        .toList()
      ..sort(
        (first, second) => first.startedAtUtc.compareTo(second.startedAtUtc),
      );
  }

  /// The most recently logged night, or null if none. Its times are a
  /// good first guess for the next night.
  SleepEpisode? lastNight() {
    for (final episode in episodes.reversed) {
      if (episode.kind == SleepKind.night && !episode.isDeleted) {
        return episode;
      }
    }
    return null;
  }

  /// The episodes on [date] that are not deleted.
  Iterable<SleepEpisode> _activeOn(String date) {
    return episodes.where(
      (episode) => episode.date == date && !episode.isDeleted,
    );
  }
}
