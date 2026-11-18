// SPDX-License-Identifier: GPL-3.0-or-later

/// The part of the settings screen for light or dark mode and the accent
/// colour.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

/// How many colour circles go in one row.
const int _swatchesPerRow = 6;

/// The size of one colour circle.
const double _swatchSize = 40;

/// Lets the user pick light, dark or system mode, and an accent colour.
class AppearanceSection extends StatelessWidget {
  /// Creates the section.
  const AppearanceSection({super.key, required this.appState});

  /// The app-wide state, holding the saved choices.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final settings = appState.settings;
    final themeMode = parseThemeMode(settings?.themeMode);
    final systemAccent = appState.systemAccentColor;
    final isSystemChosen = usesSystemAccent(
      settings?.accentColor,
      systemAccent,
    );
    final accent = chooseAccentColor(settings?.accentColor, systemAccent);

    final swatches = <Widget>[
      // The phone's own colour comes first, when it has one.
      if (systemAccent != null)
        _ColorSwatch(
          choice: AccentChoice('System', systemAccent),
          isSelected: isSystemChosen,
          icon: Icons.smartphone,
          onTap: () => appState.setAccentColor(systemAccentSetting),
        ),
      for (final choice in accentChoices)
        _ColorSwatch(
          choice: choice,
          isSelected:
              !isSystemChosen && choice.color.toARGB32() == accent.toARGB32(),
          onTap: () => appState.setAccentColor(accentColorToHex(choice.color)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Theme'),
        SegmentedButton<ThemeMode>(
          // Fill the card's width, like every other control.
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode),
              label: Text('Dark'),
            ),
          ],
          selected: {themeMode},
          showSelectedIcon: false,
          onSelectionChanged: (choice) =>
              appState.setThemeMode(choice.single.name),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Accent colour'),
        _SwatchGrid(swatches: swatches),
        if (systemAccent != null) ...[
          const SizedBox(height: 12),
          const NoteText('The first colour follows your phone.'),
        ],
      ],
    );
  }
}

/// Lays out the colour circles in rows that span the full width, with
/// the columns lined up from row to row.
class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.swatches});

  final List<Widget> swatches;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < swatches.length; start += _swatchesPerRow) {
      final rowSwatches = swatches.skip(start).take(_swatchesPerRow).toList();
      // Fill a short last row with empty spaces, so its circles stay in
      // the same columns as the rows above.
      while (rowSwatches.length < _swatchesPerRow) {
        rowSwatches.add(const SizedBox(width: _swatchSize));
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: start == 0 ? 0 : 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowSwatches,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// A round button filled with one accent colour; a tick marks the
/// chosen one.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.choice,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final AccentChoice choice;
  final bool isSelected;
  final VoidCallback onTap;

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
      label: '${choice.name} accent colour',
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: _swatchSize,
          height: _swatchSize,
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
