// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [inHabitOrder]: as added, or by colour.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/habits/habit.dart';
import 'package:ippo/modules/habits/habit_order.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Habit habit(String name, Color? color) => Habit(
    id: name,
    name: name,
    valueType: 'yes_no',
    color: color,
    isArchived: false,
    isDeleted: false,
  );

  final habits = [
    habit('Grey', const Color(0xFF757575)),
    habit('Blue', const Color(0xFF1E88E5)),
    habit('Red', const Color(0xFFE53935)),
    habit('Accent', null),
    habit('Green', const Color(0xFF43A047)),
    habit('Red too', const Color(0xFFE53935)),
  ];

  List<String> names(List<Habit> list) => [for (final h in list) h.name];

  test('as added, the order does not change', () {
    expect(
      names(inHabitOrder(habits, byColour: false, accent: Colors.orange)),
      names(habits),
    );
  });

  test('by colour: around the wheel, greys last, ties as added', () {
    expect(
      names(inHabitOrder(habits, byColour: true, accent: Colors.orange)),
      // The accent (orange) sorts as orange.
      ['Red', 'Red too', 'Accent', 'Green', 'Blue', 'Grey'],
    );
  });
}
