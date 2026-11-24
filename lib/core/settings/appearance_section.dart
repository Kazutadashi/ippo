// SPDX-License-Identifier: GPL-3.0-or-later

/// The part of the settings screen for light or dark mode and the accent
/// color.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/color_circles.dart';
import '../widgets/color_wheel.dart';
import '../widgets/section_card.dart';

/// Lets the user pick light, dark or system mode, and an accent color.
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
    final brightness = Theme.of(context).brightness;

    final swatches = <Widget>[
      // The phone's own color comes first, when it has one.
      if (systemAccent != null)
        ColorCircle(
          choice: AccentChoice(
            'System',
            accentAsShown(systemAccent, brightness, matchSystem: true),
          ),
          purpose: 'accent color',
          isSelected: isSystemChosen,
          icon: Icons.smartphone,
          onTap: () => appState.setAccentColor(systemAccentSetting),
        ),
      // Each color as the app will show it in this mode (softer than the
      // raw color on dark), so what is tapped is what the app becomes.
      for (final choice in accentChoices)
        ColorCircle(
          choice: AccentChoice(
            choice.name,
            accentAsShown(choice.color, brightness),
          ),
          purpose: 'accent color',
          isSelected:
              !isSystemChosen && choice.color.toARGB32() == accent.toARGB32(),
          onTap: () => appState.setAccentColor(accentColorToHex(choice.color)),
        ),
      // Any other color, from a wheel.
      CustomColorCircle(
        color: isSystemChosen || isPresetColor(accent) ? null : accent,
        purpose: 'accent color',
        onPicked: (color) => appState.setAccentColor(accentColorToHex(color)),
        asShown: (color) => accentAsShown(color, brightness),
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
        // For OLED screens: true black instead of dark gray.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('True black in dark mode'),
          subtitle: const Text('For OLED screens: saves power'),
          value: settings?.usesTrueBlack ?? false,
          onChanged: appState.setTrueBlack,
        ),
        const SizedBox(height: 20),
        const FieldLabel('Units for body measurements'),
        SegmentedButton<bool>(
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(value: false, label: Text('Metric (kg, cm)')),
            ButtonSegment(value: true, label: Text('Imperial (lb, ft)')),
          ],
          selected: {settings?.usesImperialUnits ?? false},
          showSelectedIcon: false,
          onSelectionChanged: (choice) =>
              appState.setUnits(choice.single ? 'imperial' : 'metric'),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Clock'),
        SegmentedButton<bool>(
          expandedInsets: EdgeInsets.zero,
          segments: [
            ButtonSegment(
              value: false,
              label: Text('24-hour (${_example(24)})'),
            ),
            ButtonSegment(
              value: true,
              label: Text('12-hour (${_example(12)})'),
            ),
          ],
          selected: {settings?.uses12HourClock ?? false},
          showSelectedIcon: false,
          onSelectionChanged: (choice) =>
              appState.setClockStyle(choice.single ? '12h' : '24h'),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Accent color'),
        ColorCircleGrid(circles: swatches),
        if (systemAccent != null) ...[
          const SizedBox(height: 12),
          const NoteText('The first color follows your phone.'),
        ],
      ],
    );
  }
}

/// An example time for the clock choice: `19:30` or `7:30 pm`.
String _example(int hours) => hours == 24 ? '19:30' : '7:30 pm';
