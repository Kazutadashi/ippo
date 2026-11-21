// SPDX-License-Identifier: GPL-3.0-or-later

/// Rows of round colour buttons, for picking a colour: the accent colour
/// in Settings, or a habit's colour.
library;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The most colour circles in one row; fewer on a narrow screen.
const int _mostPerRow = 7;

/// The area of one colour circle that can be tapped: 48, the smallest
/// tap target Android's accessibility guidance asks for.
const double colorCircleSize = 48;

/// The colour itself, inside the tap area: smaller, so a page of colours
/// is calm, with room around it for the ring that marks the chosen one.
const double colorSwatchSize = 34;

/// Lays out [circles] in rows that span the full width, with the columns
/// lined up from row to row.
class ColorCircleGrid extends StatelessWidget {
  /// Creates the grid.
  const ColorCircleGrid({super.key, required this.circles});

  /// The circles, usually [ColorCircle]s.
  final List<Widget> circles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // As many as fit side by side, up to [_mostPerRow].
        final fit = (constraints.maxWidth / colorCircleSize).floor();
        final perRow = fit.clamp(1, _mostPerRow);
        final rows = <Widget>[];
        for (var start = 0; start < circles.length; start += perRow) {
          final rowCircles = circles.skip(start).take(perRow).toList();
          // Fill a short last row with empty spaces, so its circles stay
          // in the same columns as the rows above.
          while (rowCircles.length < perRow) {
            rowCircles.add(const SizedBox(width: colorCircleSize));
          }
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rowCircles,
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// One colour in a [ColorCircleGrid]: a [colorSwatchSize] circle of
/// [color] with [mark] on it, in a [colorCircleSize] tap area, ringed in
/// the text colour when [isSelected].
class ColorSwatchButton extends StatelessWidget {
  /// Creates the button.
  const ColorSwatchButton({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.swatch,
    this.mark,
  });

  /// Whether this is the chosen colour.
  final bool isSelected;

  /// Called when tapped.
  final VoidCallback onTap;

  /// How the swatch is filled: a colour or a gradient.
  final BoxDecoration swatch;

  /// What is drawn on the swatch, such as a tick.
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: colorCircleSize,
        height: colorCircleSize,
        alignment: Alignment.center,
        // The ring: around the swatch, with a little gap.
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: colorSwatchSize,
          height: colorSwatchSize,
          decoration: swatch.copyWith(shape: BoxShape.circle),
          child: mark,
        ),
      ),
    );
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
    final markIcon = isSelected ? Icons.check : icon;
    return Semantics(
      label: '${choice.name} $purpose',
      selected: isSelected,
      button: true,
      child: ColorSwatchButton(
        isSelected: isSelected,
        onTap: onTap,
        swatch: BoxDecoration(color: choice.color),
        mark: markIcon == null
            ? null
            : Icon(markIcon, size: 20, color: markColor),
      ),
    );
  }
}
