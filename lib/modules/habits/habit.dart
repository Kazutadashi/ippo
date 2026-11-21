// SPDX-License-Identifier: GPL-3.0-or-later

/// A habit, and one day's entry for it.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/events/things.dart';
import '../../core/theme.dart';

/// The value types a habit can have. The names are stored in the data and
/// must never change. The app currently creates yes/no habits only.
const List<String> habitValueTypes = [
  'yes_no',
  'number',
  'duration',
  'time_of_day',
];

/// The longest name allowed for a habit.
const int maximumHabitNameLength = 60;

/// A habit, such as "Read 10 pages". Created by `habit_created`; see
/// "Module: habits" in `docs/data-format.md`.
class Habit {
  /// Creates a habit.
  const Habit({
    required this.id,
    required this.name,
    required this.valueType,
    required this.color,
    required this.isArchived,
    required this.isDeleted,
  });

  /// Reads a habit from its collected events. Returns null if the data is
  /// not a valid habit.
  static Habit? fromRecord(ThingRecord record) {
    final name = record.fields['name'];
    final valueType = record.fields['value_type'];
    if (name is! String || name.trim().isEmpty) {
      return null;
    }
    if (valueType is! String || !habitValueTypes.contains(valueType)) {
      return null;
    }
    return Habit(
      id: record.id,
      name: name,
      valueType: valueType,
      // A colour that is not `#RRGGBB` is treated as no colour.
      color: parseHexColor(record.fields['color']),
      isArchived: record.fields['archived'] == true,
      isDeleted: record.isDeleted,
    );
  }

  /// The habit's id.
  final String id;

  /// The habit's name.
  final String name;

  /// What is recorded each day: `yes_no`, `number`, ...
  final String valueType;

  /// The colour the user picked, or null to use the accent colour.
  final Color? color;

  /// The colour to draw the habit in, on a screen with [theme].
  ///
  /// Without a colour of its own, a habit uses the accent colour. A
  /// picked colour keeps its hue in light and dark mode alike, made just
  /// light or dark enough to read on the background: a yellow habit is
  /// a deeper yellow in light mode.
  Color displayColor(ThemeData theme) {
    final color = this.color;
    if (color == null) {
      return theme.colorScheme.primary;
    }
    return habitColourAsShown(color, theme);
  }

  /// Whether the habit is hidden without being deleted.
  final bool isArchived;

  /// Whether the habit was deleted.
  final bool isDeleted;
}

/// One day's entry for a habit. Created by `habit_entry_recorded`.
class HabitEntry {
  /// Creates an entry.
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.date,
    required this.value,
    required this.isDeleted,
  });

  /// Reads an entry from its collected events. Returns null if the data
  /// is not valid.
  static HabitEntry? fromRecord(ThingRecord record) {
    final habitId = record.fields['habit_id'];
    final date = record.fields['date'];
    if (habitId is! String || date is! String || !isValidDate(date)) {
      return null;
    }
    return HabitEntry(
      id: record.id,
      habitId: habitId,
      date: date,
      value: record.fields['value'],
      isDeleted: record.isDeleted,
    );
  }

  /// The entry's id.
  final String id;

  /// The habit.
  final String habitId;

  /// The day it counts for, `YYYY-MM-DD`.
  final String date;

  /// The recorded value: `true` or `false` for a yes/no habit. It may be
  /// missing (a skipped day, from other tools).
  final Object? value;

  /// Whether the entry was deleted.
  final bool isDeleted;
}

/// Checks a habit name the user typed. Returns null if it is fine, or a
/// message explaining what is wrong.
String? checkHabitName(String name) {
  if (name.trim().isEmpty) {
    return 'Please enter a name.';
  }
  if (name.trim().length > maximumHabitNameLength) {
    return 'Please use at most $maximumHabitNameLength characters.';
  }
  return null;
}
