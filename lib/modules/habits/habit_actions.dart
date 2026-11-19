// SPDX-License-Identifier: GPL-3.0-or-later

/// Saving changes in the habits module, as events.
///
/// The event types and fields follow `docs/data-format.md`, section
/// "Module: habits".
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/events/event.dart';
import '../../core/theme.dart';
import 'habit.dart';
import 'habit_log.dart';

/// Writes the habits module's events through [appState].
///
/// Every method throws `DataFolderException` if an event cannot be
/// saved.
class HabitActions {
  /// Creates the actions for [appState].
  HabitActions(this.appState);

  /// The app state that writes the events.
  final AppState appState;

  /// Creates a yes/no habit done once a day, drawn in [color] (null for
  /// the accent colour). Returns the event, whose id is the habit's.
  Future<Event> createHabit(String name, {Color? color}) {
    return _write('habit_created', {
      'name': name.trim(),
      'value_type': 'yes_no',
      'frequency': {'times': 1, 'per_days': 1},
      if (color != null) 'color': accentColorToHex(color),
    });
  }

  /// Gives [habit] the name [newName] and the colour [newColor] (null for
  /// the accent colour). Only what actually changed is written, so a
  /// rename on one device and a new colour on another both survive.
  /// Returns null if nothing changed.
  Future<Event?> changeHabit(
    Habit habit,
    String newName,
    Color? newColor,
  ) async {
    final changes = <String, Object?>{
      if (newName.trim() != habit.name) 'name': newName.trim(),
      if (newColor?.toARGB32() != habit.color?.toARGB32())
        'color': newColor == null ? null : accentColorToHex(newColor),
    };
    if (changes.isEmpty) {
      return null;
    }
    return _write('habit_changed', {'target_id': habit.id, 'changes': changes});
  }

  /// Deletes a habit. Its entries stay in the data.
  Future<Event> deleteHabit(String habitId) =>
      _write('habit_deleted', {'target_id': habitId});

  /// Undoes [deleteHabit].
  Future<Event> restoreHabit(String habitId) =>
      _write('habit_restored', {'target_id': habitId});

  /// Records done (true) or not done (false) for [habitId] on [date].
  Future<Event> recordDay(String habitId, String date, {required bool done}) {
    return _write('habit_entry_recorded', {
      'habit_id': habitId,
      'date': date,
      'value': done,
    });
  }

  /// Clears [date] back to "nothing recorded", by deleting every entry
  /// for that day ([log] is the current state).
  Future<void> clearDay(String habitId, String date, HabitLog log) async {
    for (final entry in log.entriesOn(habitId, date)) {
      await _write('habit_entry_deleted', {'target_id': entry.id});
    }
  }

  /// Moves [habitId]'s mark on [date] one step: nothing → done → not
  /// done → nothing.
  Future<void> cycleDay(String habitId, String date, HabitLog log) async {
    switch (log.markOn(habitId, date)) {
      case DayMark.none:
        await recordDay(habitId, date, done: true);
      case DayMark.done:
        await recordDay(habitId, date, done: false);
      case DayMark.notDone:
        await clearDay(habitId, date, log);
    }
  }

  Future<Event> _write(String type, Map<String, Object?> data) {
    return appState.writeEvent(
      module: habitsModuleName,
      type: type,
      data: data,
    );
  }
}
