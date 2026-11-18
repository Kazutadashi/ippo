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
  Future<Event> changeMoment(SleepMoment moment, DateTime at) {
    return _write('${moment.kind.eventName}_changed', {
      'target_id': moment.id,
      'changes': {'at': formatTimestamp(at)},
    });
  }

  /// Deletes [moment].
  Future<Event> deleteMoment(SleepMoment moment) {
    return _write('${moment.kind.eventName}_deleted', {'target_id': moment.id});
  }

  /// Undoes [deleteMoment].
  Future<Event> restoreMoment(SleepMoment moment) {
    return _write('${moment.kind.eventName}_restored', {
      'target_id': moment.id,
    });
  }

  /// Records a nap lasting [period] on the day [day].
  Future<Event> recordNap({
    required DateTime day,
    required SleepPeriod period,
  }) {
    return _write('nap_recorded', {
      'date': formatDate(day),
      'started_at': formatTimestamp(period.start),
      'ended_at': formatTimestamp(period.end),
    });
  }

  /// Changes the start and end of the nap [napId].
  Future<Event> changeNap(String napId, SleepPeriod period) {
    return _write('nap_changed', {
      'target_id': napId,
      'changes': {
        'started_at': formatTimestamp(period.start),
        'ended_at': formatTimestamp(period.end),
      },
    });
  }

  /// Deletes the nap [napId].
  Future<Event> deleteNap(String napId) =>
      _write('nap_deleted', {'target_id': napId});

  /// Undoes [deleteNap].
  Future<Event> restoreNap(String napId) =>
      _write('nap_restored', {'target_id': napId});

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(module: sleepModuleName, type: type, data: data);
  }
}
