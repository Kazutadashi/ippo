// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the theme helpers and for saving appearance settings.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/core/theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('accent colours', () {
    test('written as #RRGGBB and read back', () {
      const orange = Color(0xFFFB8C00);
      expect(accentColorToHex(orange), '#FB8C00');
      expect(parseAccentColor('#FB8C00').toARGB32(), orange.toARGB32());
      expect(parseAccentColor('#fb8c00').toARGB32(), orange.toARGB32());
    });

    test('missing or broken values fall back to the default', () {
      expect(parseAccentColor(null), defaultAccentColor);
      expect(parseAccentColor('orange'), defaultAccentColor);
      expect(parseAccentColor('#FB8C0'), defaultAccentColor);
    });

    test('every offered colour survives saving and loading', () {
      for (final choice in accentChoices) {
        final hex = accentColorToHex(choice.color);
        expect(
          parseAccentColor(hex).toARGB32(),
          choice.color.toARGB32(),
          reason: choice.name,
        );
      }
    });
  });

  group('choosing the accent colour', () {
    const systemBlue = Color(0xFF3366CC);
    const orangeHex = '#FB8C00';

    test('until a colour is picked, the phone\'s colour is used', () {
      expect(chooseAccentColor(null, systemBlue), systemBlue);
      expect(usesSystemAccent(null, systemBlue), isTrue);
    });

    test('"system" uses the phone\'s colour', () {
      expect(chooseAccentColor('system', systemBlue), systemBlue);
      expect(usesSystemAccent('system', systemBlue), isTrue);
    });

    test('a picked colour wins over the phone\'s colour', () {
      expect(
        chooseAccentColor(orangeHex, systemBlue).toARGB32(),
        parseAccentColor(orangeHex).toARGB32(),
      );
      expect(usesSystemAccent(orangeHex, systemBlue), isFalse);
    });

    test('without a phone colour, the default is used', () {
      expect(chooseAccentColor(null, null), defaultAccentColor);
      expect(chooseAccentColor('system', null), defaultAccentColor);
      expect(usesSystemAccent('system', null), isFalse);
    });

    test('matching the system keeps the one-shade rule', () {
      final colors = buildTheme(
        systemBlue,
        Brightness.dark,
        matchSystem: true,
      ).colorScheme;
      expect(colors.primaryContainer, colors.primary);
    });
  });

  test('theme modes are read by name, defaulting to system', () {
    expect(parseThemeMode('dark'), ThemeMode.dark);
    expect(parseThemeMode('light'), ThemeMode.light);
    expect(parseThemeMode('system'), ThemeMode.system);
    expect(parseThemeMode(null), ThemeMode.system);
    expect(parseThemeMode('sepia'), ThemeMode.system);
  });

  test('every accent-coloured part uses the same main colour', () {
    for (final brightness in Brightness.values) {
      for (final choice in accentChoices) {
        final colors = buildTheme(choice.color, brightness).colorScheme;
        final reason = '${choice.name}, $brightness';
        expect(colors.primaryContainer, colors.primary, reason: reason);
        expect(colors.secondary, colors.primary, reason: reason);
        // Highlights are a tint between the main colour and background.
        expect(colors.secondaryContainer, isNot(colors.primary));
        expect(colors.secondaryContainer, isNot(colors.surface));
      }
    }
  });

  test('themes are light or dark as asked', () {
    const orange = Color(0xFFFB8C00);
    expect(buildTheme(orange, Brightness.light).brightness, Brightness.light);
    expect(buildTheme(orange, Brightness.dark).brightness, Brightness.dark);
  });

  group('saving appearance settings', () {
    late Directory settingsFolder;

    setUp(() {
      settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    });

    tearDown(() {
      settingsFolder.deleteSync(recursive: true);
    });

    AppState makeAppState() => AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );

    test('theme and colour are kept after a restart', () async {
      final firstRun = makeAppState();
      await firstRun.load();
      await firstRun.setThemeMode('dark');
      await firstRun.setAccentColor('#FB8C00');

      final secondRun = makeAppState();
      await secondRun.load();

      final settings = secondRun.settings!;
      expect(settings.themeMode, 'dark');
      expect(settings.accentColor, '#FB8C00');
      // Changing one setting does not lose the others.
      expect(settings.deviceId, firstRun.settings!.deviceId);
    });

    test('settings saved before these options existed still load', () async {
      File('${settingsFolder.path}/settings.json').writeAsStringSync(
        '{"device_id": "019a8f3c-0000-7000-8000-000000000001", '
        '"device_name": "my-desktop", "linux_data_folder_path": null}',
      );

      final appState = makeAppState();
      await appState.load();

      expect(appState.settings!.themeMode, isNull);
      expect(appState.settings!.accentColor, isNull);
      expect(appState.errorMessage, isNull);
    });
  });

  test('a habit colour is shifted just enough to read on any background', () {
    const amber = Color(0xFFFFB300);
    const white = Color(0xFFFFFFFF);
    const nearBlack = Color(0xFF141414);
    // Too pale on white: made darker, keeping its hue.
    final onLight = readableOn(amber, white);
    expect(contrastRatio(onLight, white), greaterThanOrEqualTo(3));
    expect(
      HSLColor.fromColor(onLight).hue,
      closeTo(HSLColor.fromColor(amber).hue, 1),
    );
    // Already readable on black: unchanged.
    expect(readableOn(amber, nearBlack), amber);
  });

  test('dark mode has white text, and true black when chosen', () {
    final dark = buildTheme(const Color(0xFF00897B), Brightness.dark);
    expect(dark.colorScheme.onSurface, Colors.white);
    final black = buildTheme(
      const Color(0xFF00897B),
      Brightness.dark,
      trueBlack: true,
    );
    expect(black.colorScheme.surface, Colors.black);
  });
}
