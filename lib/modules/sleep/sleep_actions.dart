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

  /// Records a night or nap lasting [period], counting for the day [day].
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

  /// Changes the start and end of an episode.
  Future<Event> changeSleep(String episodeId, SleepPeriod period) {
    return _write('sleep_changed', {
      'target_id': episodeId,
      'changes': {
        'started_at': formatTimestamp(period.start),
        'ended_at': formatTimestamp(period.end),
      },
    });
  }

  /// Deletes an episode.
  Future<Event> deleteSleep(String episodeId) =>
      _write('sleep_deleted', {'target_id': episodeId});

  /// Undoes [deleteSleep].
  Future<Event> restoreSleep(String episodeId) =>
      _write('sleep_restored', {'target_id': episodeId});

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(module: sleepModuleName, type: type, data: data);
  }
}
