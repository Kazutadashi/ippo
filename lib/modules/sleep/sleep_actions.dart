// SPDX-License-Identifier: GPL-3.0-or-later

/// Saving changes in the sleep module, as events.
///
/// The event types and fields follow `docs/data-format.md`, section
/// "Module: sleep".
library;

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/events/event.dart';
import '../../core/events/timestamp.dart';
import 'sleep_episode.dart';
import 'sleep_log.dart';
import 'sleep_moment.dart';
import 'sleep_times.dart';

/// Writes the sleep module's events through [appState].
///
/// Every method throws `DataFolderException` if the event cannot be
/// saved; nothing is saved then.
class SleepActions {
  /// Creates the actions for [appState].
  SleepActions(this.appState);

  /// The app state that writes the events.
  final AppState appState;

  /// Records that you woke up, or went to bed, at the moment [at], for
  /// the day [day] (a day runs from waking up to going to bed).
  Future<Event> recordMoment({
    required MomentKind kind,
    required DateTime day,
    required DateTime at,
  }) {
    return _write('${kind.eventName}_recorded', {
      'date': formatDate(day),
      'at': formatTimestamp(at),
    });
  }

  /// Changes the time of [moment] to [at].
  ///
  /// A moment taken from a whole night saved by an older version gets a
  /// new record of its own instead, which takes its place; the old night
  /// stays in the file, unchanged.
  Future<Event> changeMoment(SleepMoment moment, DateTime at) {
    if (moment.oldNightId != null) {
      return recordMoment(
        kind: moment.kind,
        day: parseDate(moment.date)!,
        at: at,
      );
    }
    return _write('${moment.kind.eventName}_changed', {
      'target_id': moment.id,
      'changes': {'at': formatTimestamp(at)},
    });
  }

  /// Deletes [moment].
  ///
  /// A moment taken from a whole night saved by an older version deletes
  /// that night, which also removes the other moment it held.
  Future<Event> deleteMoment(SleepMoment moment) {
    final oldNightId = moment.oldNightId;
    if (oldNightId != null) {
      return deleteSleep(oldNightId);
    }
    return _write('${moment.kind.eventName}_deleted', {'target_id': moment.id});
  }

  /// Undoes [deleteMoment].
  Future<Event> restoreMoment(SleepMoment moment) {
    final oldNightId = moment.oldNightId;
    if (oldNightId != null) {
      return restoreSleep(oldNightId);
    }
    return _write('${moment.kind.eventName}_restored', {
      'target_id': moment.id,
    });
  }

  /// Records a nap lasting [period] on the day [day].
  ///
  /// (Whole nights were also saved this way by older versions.)
  Future<Event> recordSleep({
    required DateTime day,
    required SleepKind kind,
    required SleepPeriod period,
  }) {
    return _write('sleep_recorded', {
      'date': formatDate(day),
      'kind': kind.name,
      'started_at': formatTimestamp(period.start),
      'ended_at': formatTimestamp(period.end),
    });
  }

  /// Changes the start and end of a nap.
  Future<Event> changeSleep(String episodeId, SleepPeriod period) {
    return _write('sleep_changed', {
      'target_id': episodeId,
      'changes': {
        'started_at': formatTimestamp(period.start),
        'ended_at': formatTimestamp(period.end),
      },
    });
  }

  /// Deletes a nap (or an older whole night).
  Future<Event> deleteSleep(String episodeId) =>
      _write('sleep_deleted', {'target_id': episodeId});

  /// Undoes [deleteSleep].
  Future<Event> restoreSleep(String episodeId) =>
      _write('sleep_restored', {'target_id': episodeId});

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(module: sleepModuleName, type: type, data: data);
  }
}
