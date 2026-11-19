// SPDX-License-Identifier: GPL-3.0-or-later

/// Saving body measurements and the energy target, as events.
///
/// The event types and fields follow `docs/data-format.md`, section
/// "Module: body".
library;

import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/number_input.dart';
import 'body_log.dart';

/// Writes the body module's events through [appState].
///
/// Every method throws `DataFolderException` if the event cannot be
/// saved; nothing is saved then.
class BodyActions {
  /// Creates the actions for [appState].
  BodyActions(this.appState);

  /// The app state that writes the events.
  final AppState appState;

  /// Saves sex, year of birth and height; a later record replaces them.
  Future<Event> saveProfile({
    required Sex sex,
    required int birthYear,
    required double heightCm,
  }) {
    return _write('profile_recorded', {
      'sex': sex.name,
      'birth_year': birthYear,
      'height_cm': jsonNumber(heightCm),
    });
  }

  /// Saves the weight on [date]: a new weighing, or a change to the
  /// day's weighing if there is one ([existing]).
  Future<Event> saveWeight({
    required String date,
    required double weightKg,
    required WeightEntry? existing,
  }) {
    if (existing == null) {
      return _write('weight_recorded', {
        'date': date,
        'weight_kg': jsonNumber(weightKg),
      });
    }
    return _write('weight_changed', {
      'target_id': existing.id,
      'changes': {'weight_kg': jsonNumber(weightKg)},
    });
  }

  /// Sets the daily energy target from [date] on; null removes it.
  Future<Event> setEnergyTarget({
    required String date,
    required double? energyKcal,
  }) {
    return _write('energy_target_recorded', {
      'date': date,
      if (energyKcal != null) 'energy_kcal': jsonNumber(energyKcal),
    });
  }

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(module: bodyModuleName, type: type, data: data);
  }
}
