// SPDX-License-Identifier: GPL-3.0-or-later

/// The settings that belong to one install of the app.
library;

import '../events/uuid_v7.dart';

/// The longest device name allowed, in characters.
const int maximumDeviceNameLength = 40;

/// Settings for this install of the app, saved in `settings.json`.
///
/// They are separate from the shared data in the data folder, because
/// each device has its own.
class AppSettings {
  /// Creates settings with the given values.
  const AppSettings({
    required this.deviceId,
    required this.deviceName,
    required this.linuxDataFolderPath,
    required this.themeMode,
    required this.accentColor,
    required this.clockStyle,
    this.usesTrueBlack = false,
    this.units,
  });

  /// Creates settings for a fresh install: a new random device id and
  /// the name [defaultDeviceName].
  factory AppSettings.createNew(String defaultDeviceName) {
    return AppSettings(
      deviceId: generateUuidV7(),
      deviceName: defaultDeviceName,
      linuxDataFolderPath: null,
      themeMode: null,
      accentColor: null,
      clockStyle: null,
    );
  }

  /// Reads settings saved by [toJson].
  ///
  /// Returns null if [json] has no valid device id, because without one
  /// the device could not find its own event file. Other missing values
  /// fall back to defaults.
  static AppSettings? fromJson(
    Map<String, Object?> json, {
    required String defaultDeviceName,
  }) {
    final deviceId = json['device_id'];
    if (deviceId is! String || !isValidUuid(deviceId)) {
      return null;
    }
    final deviceName = json['device_name'];
    return AppSettings(
      deviceId: deviceId,
      deviceName: deviceName is String && checkDeviceName(deviceName) == null
          ? deviceName
          : defaultDeviceName,
      linuxDataFolderPath: _textOrNull(json['linux_data_folder_path']),
      themeMode: _textOrNull(json['theme_mode']),
      accentColor: _textOrNull(json['accent_color']),
      clockStyle: _textOrNull(json['clock_style']),
      usesTrueBlack: json['true_black'] == true,
      units: _textOrNull(json['units']),
    );
  }

  /// This install's random id. It names this device's event file and
  /// never changes.
  final String deviceId;

  /// A name for this device chosen by the user, such as `my-phone`.
  /// Only for display; it can change at any time.
  final String deviceName;

  /// On Linux, the absolute path of the data folder, or null if none is
  /// chosen yet. Not used on Android, where Android itself remembers the
  /// chosen folder.
  final String? linuxDataFolderPath;

  /// `system`, `light` or `dark`, or null for the default (system).
  final String? themeMode;

  /// The accent colour as `#RRGGBB`, or null for the default.
  final String? accentColor;

  /// How times are shown: `24h` ("19:30") or `12h` ("7:30 pm"), or null
  /// for the default (24 hours).
  final String? clockStyle;

  /// Whether dark mode uses a true black background, which saves power
  /// on OLED screens and has the strongest contrast.
  final bool usesTrueBlack;

  /// How measurements are shown: `metric` (kg, cm) or `imperial` (lb,
  /// feet and inches), or null for the default (metric). The data is
  /// always metric.
  final String? units;

  /// Whether measurements are shown in imperial units.
  bool get usesImperialUnits => units == 'imperial';

  /// Whether times are shown on a 12-hour clock.
  bool get uses12HourClock => clockStyle == '12h';

  /// Returns a copy with the given values changed.
  AppSettings copyWith({
    String? deviceName,
    String? linuxDataFolderPath,
    String? themeMode,
    String? accentColor,
    String? clockStyle,
    bool? usesTrueBlack,
    String? units,
  }) {
    return AppSettings(
      deviceId: deviceId,
      deviceName: deviceName ?? this.deviceName,
      linuxDataFolderPath: linuxDataFolderPath ?? this.linuxDataFolderPath,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      clockStyle: clockStyle ?? this.clockStyle,
      usesTrueBlack: usesTrueBlack ?? this.usesTrueBlack,
      units: units ?? this.units,
    );
  }

  /// Turns the settings into JSON for `settings.json`.
  Map<String, Object?> toJson() => {
    'device_id': deviceId,
    'device_name': deviceName,
    'linux_data_folder_path': linuxDataFolderPath,
    'theme_mode': themeMode,
    'accent_color': accentColor,
    'clock_style': clockStyle,
    'true_black': usesTrueBlack,
    'units': units,
  };
}

/// Checks a device name the user typed.
///
/// Returns null if [name] is fine, or a message explaining what is
/// wrong. A name must not be empty or only spaces, and must be at most
/// [maximumDeviceNameLength] characters.
String? checkDeviceName(String name) {
  if (name.trim().isEmpty) {
    return 'Please enter a name.';
  }
  if (name.length > maximumDeviceNameLength) {
    return 'Please use at most $maximumDeviceNameLength characters.';
  }
  return null;
}

/// Returns [value] if it is text, otherwise null.
String? _textOrNull(Object? value) => value is String ? value : null;
