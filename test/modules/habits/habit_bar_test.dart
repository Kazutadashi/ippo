// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [HabitBar]: it fits any number of habits.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/habits/habit.dart';
import 'package:ippo/modules/habits/habit_log.dart';
import 'package:ippo/modules/habits/habit_marks.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  List<Habit> habits(int count) => [
    for (var index = 0; index < count; index++)
      Habit(
        id: 'habit-$index',
        name: 'Habit $index',
        valueType: 'yes_no',
        color: null,
        isArchived: false,
        isDeleted: false,
      ),
  ];

  /// How many rows the bar for [count] habits has, in a narrow tile.
  Future<int> rowsFor(WidgetTester tester, int count) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            // About the width of a Home tile on a small phone.
            child: SizedBox(
              width: 140,
              child: HabitBar(
                habits: habits(count),
                log: HabitLog.fromEvents(const []),
                date: '2026-11-20',
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return find
        .descendant(of: find.byType(HabitBar), matching: find.byType(Row))
        .evaluate()
        .length;
  }

  testWidgets('more habits go on more rows, never off the tile', (
    tester,
  ) async {
    expect(await rowsFor(tester, 1), 1);
    expect(await rowsFor(tester, 5), 1);
    expect(await rowsFor(tester, 8), 1);
    expect(await rowsFor(tester, 15), 2);
    expect(await rowsFor(tester, 24), 3);
    // At most four rows; past that, rows get longer.
    expect(await rowsFor(tester, 40), 4);
  });
}
