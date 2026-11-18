// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module's current state, worked out from the event log.
library;

import '../../core/events/event.dart';
import '../../core/events/things.dart';
import 'habit.dart';

/// The module's name in event files. Never change it.
const String habitsModuleName = 'habits';

/// What a yes/no habit shows on one day.
enum DayMark {
  /// Nothing recorded.
  none,

  /// Done: recorded as yes.
  done,

  /// Not done: recorded as no.
  notDone,
}

/// All habits and entries, with every change applied.
class HabitLog {
  /// Creates a log. Normal code uses [HabitLog.fromEvents].
  HabitLog({
    required this.habits,
    required this.entries,
    required this.invalidCount,
  });

  /// Builds the log from the event log's events (oldest first).
  factory HabitLog.fromEvents(List<Event> events) {
    var invalidCount = 0;
    final habits = <String, Habit>{};
    for (final record in collectThings(
      events,
      module: habitsModuleName,
      createdType: 'habit_created',
      thingName: 'habit',
    ).values) {
      final habit = Habit.fromRecord(record);
      if (habit == null) {
        invalidCount++;
      } else {
        habits[habit.id] = habit;
      }
    }
    final entries = <HabitEntry>[];
    for (final record in collectThings(
      events,
      module: habitsModuleName,
      createdType: 'habit_entry_recorded',
      thingName: 'habit_entry',
    ).values) {
      final entry = HabitEntry.fromRecord(record);
      if (entry == null) {
        invalidCount++;
      } else {
        entries.add(entry);
      }
    }
    return HabitLog(
      habits: habits,
      entries: entries,
      invalidCount: invalidCount,
    );
  }

  /// Every habit by id, including deleted ones.
  final Map<String, Habit> habits;

  /// Every entry, including deleted ones, in the order they were made.
  final List<HabitEntry> entries;

  /// How many things were skipped because their data was not valid.
  final int invalidCount;

  /// The yes/no habits shown, in the order they were created: not
  /// deleted and not archived.
  List<Habit> get shownHabits => habits.values
      .where(
        (habit) =>
            !habit.isDeleted &&
            !habit.isArchived &&
            habit.valueType == 'yes_no',
      )
      .toList();

  /// The entries of [habitId] on [date] that are not deleted, oldest
  /// first. The last one counts.
  List<HabitEntry> entriesOn(String habitId, String date) {
    return entries
        .where(
          (entry) =>
              entry.habitId == habitId &&
              entry.date == date &&
              !entry.isDeleted,
        )
        .toList();
  }

  /// What [habitId] shows on [date].
  DayMark markOn(String habitId, String date) {
    final dayEntries = entriesOn(habitId, date);
    if (dayEntries.isEmpty) {
      return DayMark.none;
    }
    final value = dayEntries.last.value;
    if (value == true) {
      return DayMark.done;
    }
    if (value == false) {
      return DayMark.notDone;
    }
    return DayMark.none;
  }
}
