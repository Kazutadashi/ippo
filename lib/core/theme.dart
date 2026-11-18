// SPDX-License-Identifier: GPL-3.0-or-later

/// The app's look: light or dark, and the accent colour the user chose.
library;

import 'package:material_ui/material_ui.dart';

/// One accent colour the user can pick.
class AccentChoice {
  /// Creates a choice named [name] with [color].
  const AccentChoice(this.name, this.color);

  /// The colour's name, read out by screen readers.
  final String name;

  /// The colour itself.
  final Color color;
}

/// The accent colours offered in settings.
const List<AccentChoice> accentChoices = [
  AccentChoice('Red', Color(0xFFE53935)),
  AccentChoice('Orange', Color(0xFFFB8C00)),
  AccentChoice('Amber', Color(0xFFFFB300)),
  AccentChoice('Green', Color(0xFF43A047)),
  AccentChoice('Teal', Color(0xFF00897B)),
  AccentChoice('Blue', Color(0xFF1E88E5)),
  AccentChoice('Indigo', Color(0xFF3949AB)),
  AccentChoice('Purple', Color(0xFF8E24AA)),
  AccentChoice('Pink', Color(0xFFD81B60)),
  AccentChoice('Brown', Color(0xFF6D4C41)),
  AccentChoice('Grey', Color(0xFF757575)),
];

/// The accent colour until the user picks one.
const Color defaultAccentColor = Color(0xFF00897B);

/// Matches a colour written as `#RRGGBB`.
final RegExp _hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Reads a colour saved by [accentColorToHex]. Returns
/// [defaultAccentColor] if [hex] is missing or not a `#RRGGBB` colour.
Color parseAccentColor(String? hex) {
  if (hex == null || !_hexColorPattern.hasMatch(hex)) {
    return defaultAccentColor;
  }
  final rgb = int.parse(hex.substring(1), radix: 16);
  return Color(0xFF000000 | rgb);
}

/// Writes [color] as `#RRGGBB`, for saving in the settings file.
String accentColorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Reads a theme mode saved by its name (`system`, `light` or `dark`).
/// Anything else means [ThemeMode.system].
ThemeMode parseThemeMode(String? name) {
  for (final mode in ThemeMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return ThemeMode.system;
}

/// Builds the app's theme from the [accent] colour, light or dark.
///
/// "Fidelity" keeps the main colour close to the chosen one, so picking
/// orange really gives orange rather than a muted shade of it.
ThemeData buildTheme(Color accent, Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
  );
}
