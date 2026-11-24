// SPDX-License-Identifier: GPL-3.0-or-later

/// The order habits are listed in: as added, or by color.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import 'habit.dart';
import 'habit_log.dart';

/// [habits] in the order to show them. As added, they stay as they are.
/// By color, they go around the color wheel (red, orange, yellow,
/// green, blue, purple), with grays and browns (colors with little hue)
/// at the end; habits of the same color keep the order they were added
/// in. A habit without its own color counts as [accent], the color it
/// is shown in.
List<Habit> inHabitOrder(
  List<Habit> habits, {
  required bool byColor,
  required Color accent,
}) {
  if (!byColor) {
    return habits;
  }

  /// Where a habit's color sorts: its hue (0–360), or past every hue for
  /// a color too gray to have one.
  double place(Habit habit) {
    final color = HSVColor.fromColor(habit.color ?? accent);
    return color.saturation < 0.25 ? 360 + color.value : color.hue;
  }

  final numbered = habits.indexed.toList()
    ..sort((a, b) {
      final byPlace = place(a.$2).compareTo(place(b.$2));
      return byPlace != 0 ? byPlace : a.$1.compareTo(b.$1);
    });
  return [for (final (_, habit) in numbered) habit];
}

/// The habits to show, in the order chosen on the Habits tab (as added,
/// or by color), the same on Home and on the tab.
List<Habit> habitsInOrder(AppState appState, HabitLog log) {
  final settings = appState.settings;
  return inHabitOrder(
    log.shownHabits,
    byColor: settings?.sortsHabitsByColor ?? false,
    accent: chooseAccentColor(
      settings?.accentColor,
      appState.systemAccentColor,
    ),
  );
}
