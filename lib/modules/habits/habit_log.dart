// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module's current state, worked out from the event log.
library;

import '../../core/app_state.dart';
import '../../core/dates.dart';
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

  /// The current state for [appState], worked out once per change of
  /// the data and shared by every screen (see `AppState.derived`).
  static HabitLog of(AppState appState) =>
      appState.derived('habit_log', HabitLog.fromEvents);

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
    return _entriesByHabitAndDay['$habitId $date'] ?? const [];
  }

  /// The entries that are not deleted, grouped by habit and day (the key
  /// is `"<habit id> <date>"`), in the order they were made. Built once,
  /// the first time it is needed, so the habit grid does not search
  /// through every entry for each of its cells.
  late final Map<String, List<HabitEntry>> _entriesByHabitAndDay = () {
    final grouped = <String, List<HabitEntry>>{};
    for (final entry in entries) {
      if (!entry.isDeleted) {
        grouped
            .putIfAbsent('${entry.habitId} ${entry.date}', () => [])
            .add(entry);
      }
    }
    return grouped;
  }();

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

  /// How many days in a row [habitId] was done, up to and including
  /// [day]. If [day] has no mark yet (the day is not over), the streak
  /// counts up to the day before, so it does not drop to zero each
  /// morning. A "not done" mark, or a day with nothing recorded, ends it.
  int streakOn(String habitId, DateTime day) {
    var current = day;
    if (markOn(habitId, formatDate(current)) == DayMark.none) {
      current = addDays(current, -1);
    }
    var streak = 0;
    while (markOn(habitId, formatDate(current)) == DayMark.done) {
      streak++;
      current = addDays(current, -1);
    }
    return streak;
  }
}
