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

/// The accent colour until the user picks one, when the phone has no
/// system colour (Linux, or Android before version 12).
const Color defaultAccentColor = Color(0xFF00897B);

/// The saved accent setting meaning "use the phone's system colour".
const String systemAccentSetting = 'system';

/// Works out which accent colour to use.
///
/// [savedSetting] is the setting from `settings.json`: `system`, a
/// `#RRGGBB` colour, or null if never set. [systemAccent] is the phone's
/// own accent, or null if it has none. Until the user picks a colour,
/// the phone's colour is used, so Ippo matches the rest of the phone.
Color chooseAccentColor(String? savedSetting, Color? systemAccent) {
  final wantsSystem =
      savedSetting == null || savedSetting == systemAccentSetting;
  if (wantsSystem) {
    return systemAccent ?? defaultAccentColor;
  }
  return parseAccentColor(savedSetting);
}

/// Returns true if the system colour is in use (see [chooseAccentColor]).
bool usesSystemAccent(String? savedSetting, Color? systemAccent) {
  final wantsSystem =
      savedSetting == null || savedSetting == systemAccentSetting;
  return wantsSystem && systemAccent != null;
}

/// Matches a colour written as `#RRGGBB`.
final RegExp _hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Reads a colour saved by [accentColorToHex]. Returns
/// [defaultAccentColor] if [hex] is missing or not a `#RRGGBB` colour.
Color parseAccentColor(String? hex) => parseHexColor(hex) ?? defaultAccentColor;

/// Reads a colour written as `#RRGGBB`. Returns null if [hex] is not
/// one, for example missing or from a tool that wrote something else.
Color? parseHexColor(Object? hex) {
  if (hex is! String || !_hexColorPattern.hasMatch(hex)) {
    return null;
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
/// Flutter works out a full set of colours from the accent: a main
/// colour for buttons, plus "container" colours for other things. Left
/// alone, those come out as several different shades (for example
/// bright orange, pale peach and brown), which looks unrelated. So every
/// accent-coloured part uses the one main colour here, and highlights
/// such as the selected tab use a light tint of it.
///
/// The main colour is the accent adjusted for light or dark mode, so
/// text on it stays readable. "Fidelity" keeps it close to the chosen
/// colour. See `lib/core/widgets/section_card.dart` for the rest of the
/// look.
///
/// With [matchSystem], the colours are worked out the way Android works
/// out its own ("tonal spot"), so they match the rest of the phone.
///
/// In dark mode, text is pure white rather than the theme's tinted
/// off-white, for the clearest contrast. With [trueBlack], the dark
/// background is true black too (which saves power on OLED screens),
/// and cards are the darkest greys that still show their edges.
ThemeData buildTheme(
  Color accent,
  Brightness brightness, {
  bool matchSystem = false,
  bool trueBlack = false,
}) {
  final generated = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    dynamicSchemeVariant: matchSystem
        ? DynamicSchemeVariant.tonalSpot
        : DynamicSchemeVariant.fidelity,
  );
  final main = generated.primary;
  final onMain = generated.onPrimary;
  // A light tint of the main colour over the background.
  final tint = Color.alphaBlend(
    main.withValues(alpha: 0.25),
    generated.surface,
  );
  final isDark = brightness == Brightness.dark;
  final colorScheme = generated.copyWith(
    // Main text pure white in dark mode; grey text stays grey.
    onSurface: isDark ? Colors.white : null,
    surface: isDark && trueBlack ? Colors.black : null,
    surfaceContainerLowest: isDark && trueBlack ? Colors.black : null,
    surfaceContainerLow: isDark && trueBlack ? const Color(0xFF0B0B0B) : null,
    surfaceContainer: isDark && trueBlack ? const Color(0xFF141414) : null,
    surfaceContainerHigh: isDark && trueBlack ? const Color(0xFF1C1C1C) : null,
    surfaceContainerHighest: isDark && trueBlack
        ? const Color(0xFF242424)
        : null,
    primaryContainer: main,
    onPrimaryContainer: onMain,
    secondary: main,
    onSecondary: onMain,
    secondaryContainer: tint,
    onSecondaryContainer: generated.onSurface,
  );
  final theme = ThemeData(
    colorScheme: colorScheme,
    // Compact density: Ippo is a logging tool, so it shows more at once.
    // Fields, buttons and list rows look smaller, but every tap target
    // stays at least 48 × 48, as accessibility guidance asks.
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Every text field gets an outline, so anything the user can change
    // looks the same on every screen.
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
      // The label always sits on the border, so a field's unit ("kcal")
      // and example ("2 slices") show before anything is typed.
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    listTileTheme: const ListTileThemeData(
      visualDensity: VisualDensity.compact,
    ),
    // Flat cards on a slightly different surface, the same in light and
    // dark mode (Material's "filled" cards, meant for dense screens).
    cardTheme: CardThemeData(elevation: 0, color: colorScheme.surfaceContainer),
    // Chips show logged things, such as a set of 20 reps. Filled with
    // the light accent tint, they look like data, never like an empty
    // text field.
    chipTheme: ChipThemeData(backgroundColor: tint, side: BorderSide.none),
    // A slightly lower title bar than Material's 64, so more of each
    // screen is content; the same on every screen.
    // It also keeps the page's colour when content scrolls under it:
    // Material would switch it to a lighter grey, which looks like a
    // stray box (on the Habits grid in landscape, for example). A plain
    // colour here is used whether or not anything is under it.
    appBarTheme: AppBarTheme(
      toolbarHeight: 52,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
  );
  return theme.copyWith(textTheme: _withTabularDigits(theme.textTheme));
}

/// Gives every text style digits of equal width, so numbers line up in
/// columns and a value that changes ("25 min ago") does not shift
/// sideways.
TextTheme _withTabularDigits(TextTheme textTheme) {
  TextStyle? tabular(TextStyle? style) =>
      style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  return textTheme.copyWith(
    displayLarge: tabular(textTheme.displayLarge),
    displayMedium: tabular(textTheme.displayMedium),
    displaySmall: tabular(textTheme.displaySmall),
    headlineLarge: tabular(textTheme.headlineLarge),
    headlineMedium: tabular(textTheme.headlineMedium),
    headlineSmall: tabular(textTheme.headlineSmall),
    titleLarge: tabular(textTheme.titleLarge),
    titleMedium: tabular(textTheme.titleMedium),
    titleSmall: tabular(textTheme.titleSmall),
    bodyLarge: tabular(textTheme.bodyLarge),
    bodyMedium: tabular(textTheme.bodyMedium),
    bodySmall: tabular(textTheme.bodySmall),
    labelLarge: tabular(textTheme.labelLarge),
    labelMedium: tabular(textTheme.labelMedium),
    labelSmall: tabular(textTheme.labelSmall),
  );
}

/// The contrast that marks and large text need against their background
/// (WCAG's level for graphics and large text).
const double readableContrast = 3;

/// [color], made only as much lighter or darker as it takes to stand out
/// against [background] by at least [readableContrast]. Its hue stays,
/// so a habit's colour is still its own: on a light card a yellow
/// becomes a deeper yellow, on a dark card a navy becomes a brighter
/// blue. A colour that already stands out is returned as it is.
Color readableOn(Color color, Color background) {
  final isDarkBackground = background.computeLuminance() < 0.5;
  var hsl = HSLColor.fromColor(color);
  // Small steps towards white on dark, towards black on light; at most
  // twenty, which covers the whole range of lightness.
  for (var step = 0; step < 20; step++) {
    if (contrastRatio(hsl.toColor(), background) >= readableContrast) {
      break;
    }
    final lightness = hsl.lightness + (isDarkBackground ? 0.05 : -0.05);
    hsl = hsl.withLightness(lightness.clamp(0.0, 1.0));
  }
  return hsl.toColor();
}

/// How much two colours differ in brightness, from 1 (the same) to 21
/// (black on white), as WCAG defines it.
double contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
