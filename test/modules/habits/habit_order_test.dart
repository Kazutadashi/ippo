// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [inHabitOrder]: as added, or by color.
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
    habit('Gray', const Color(0xFF757575)),
    habit('Blue', const Color(0xFF1E88E5)),
    habit('Red', const Color(0xFFE53935)),
    habit('Accent', null),
    habit('Green', const Color(0xFF43A047)),
    habit('Red too', const Color(0xFFE53935)),
  ];

  List<String> names(List<Habit> list) => [for (final h in list) h.name];

  test('as added, the order does not change', () {
    expect(
      names(inHabitOrder(habits, byColor: false, accent: Colors.orange)),
      names(habits),
    );
  });

  test('by color: around the wheel, grays last, ties as added', () {
    expect(
      names(inHabitOrder(habits, byColor: true, accent: Colors.orange)),
      // The accent (orange) sorts as orange.
      ['Red', 'Red too', 'Accent', 'Green', 'Blue', 'Gray'],
    );
  });
}
