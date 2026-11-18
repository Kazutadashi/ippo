// SPDX-License-Identifier: GPL-3.0-or-later

/// A row of buttons for choosing the meal.
library;

import 'package:material_ui/material_ui.dart';

import '../food_entry.dart';

/// Lets the user choose one meal.
class MealPicker extends StatelessWidget {
  /// Creates the picker, showing [selected] and reporting changes to
  /// [onChanged].
  const MealPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// The chosen meal.
  final Meal selected;

  /// Called with the new meal when the user picks one.
  final ValueChanged<Meal> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Meal>(
      segments: [
        for (final meal in Meal.values)
          ButtonSegment(value: meal, label: Text(meal.label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (choice) => onChanged(choice.single),
    );
  }
}
