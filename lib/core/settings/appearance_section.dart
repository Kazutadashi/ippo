// SPDX-License-Identifier: GPL-3.0-or-later

/// The part of the settings screen for light or dark mode and the accent
/// colour.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ThemeMode>(
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
        const SizedBox(height: 16),
        Text(
          systemAccent == null
              ? 'Accent colour'
              : 'Accent colour (the first one follows your phone\'s '
                    'system colours)',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
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
                    !isSystemChosen &&
                    choice.color.toARGB32() == accent.toARGB32(),
                onTap: () =>
                    appState.setAccentColor(accentColorToHex(choice.color)),
              ),
          ],
        ),
      ],
    );
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

  /// Shown on the swatch when it is not selected, for example a phone
  /// icon on the system colour.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // White or black tick, whichever is easier to see on this colour.
    final tickColor =
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
          width: 40,
          height: 40,
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
          child: Icon(isSelected ? Icons.check : icon, color: tickColor),
        ),
      ),
    );
  }
}
