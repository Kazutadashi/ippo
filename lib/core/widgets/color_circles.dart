// SPDX-License-Identifier: GPL-3.0-or-later

/// Rows of round colour buttons, for picking a colour: the accent colour
/// in Settings, or a habit's colour.
library;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// How many colour circles go in one row.
const int _circlesPerRow = 6;

/// The size of one colour circle.
const double _circleSize = 40;

/// Lays out [circles] in rows that span the full width, with the columns
/// lined up from row to row.
class ColorCircleGrid extends StatelessWidget {
  /// Creates the grid.
  const ColorCircleGrid({super.key, required this.circles});

  /// The circles, usually [ColorCircle]s.
  final List<Widget> circles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < circles.length; start += _circlesPerRow) {
      final rowCircles = circles.skip(start).take(_circlesPerRow).toList();
      // Fill a short last row with empty spaces, so its circles stay in
      // the same columns as the rows above.
      while (rowCircles.length < _circlesPerRow) {
        rowCircles.add(const SizedBox(width: _circleSize));
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: start == 0 ? 0 : 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowCircles,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// A round button filled with one colour; a tick marks the chosen one.
class ColorCircle extends StatelessWidget {
  /// Creates a circle for [choice].
  const ColorCircle({
    super.key,
    required this.choice,
    required this.isSelected,
    required this.onTap,
    required this.purpose,
    this.icon,
  });

  /// The colour, and its name.
  final AccentChoice choice;

  /// Whether this colour is the chosen one.
  final bool isSelected;

  /// Called when the circle is tapped.
  final VoidCallback onTap;

  /// What the colour is for, read out after its name by screen readers:
  /// "accent colour" gives "Orange accent colour".
  final String purpose;

  /// Shown on the circle when it is not selected, for example a phone
  /// icon on the system colour.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // White or black marks, whichever is easier to see on this colour.
    final markColor =
        ThemeData.estimateBrightnessForColor(choice.color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      label: '${choice.name} $purpose',
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: _circleSize,
          height: _circleSize,
          decoration: BoxDecoration(
            color: choice.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(isSelected ? Icons.check : icon, color: markColor),
        ),
      ),
    );
  }
}
