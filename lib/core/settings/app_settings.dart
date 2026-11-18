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
  });

  /// Creates settings for a fresh install: a new random device id and
  /// the name [defaultDeviceName].
  factory AppSettings.createNew(String defaultDeviceName) {
    return AppSettings(
      deviceId: generateUuidV7(),
      deviceName: defaultDeviceName,
      linuxDataFolderPath: null,
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
    final linuxDataFolderPath = json['linux_data_folder_path'];
    return AppSettings(
      deviceId: deviceId,
      deviceName: deviceName is String && checkDeviceName(deviceName) == null
          ? deviceName
          : defaultDeviceName,
      linuxDataFolderPath: linuxDataFolderPath is String
          ? linuxDataFolderPath
          : null,
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

  /// Returns a copy with a different device name.
  AppSettings withDeviceName(String newDeviceName) => AppSettings(
    deviceId: deviceId,
    deviceName: newDeviceName,
    linuxDataFolderPath: linuxDataFolderPath,
  );

  /// Returns a copy with a different Linux data folder.
  AppSettings withLinuxDataFolderPath(String newPath) => AppSettings(
    deviceId: deviceId,
    deviceName: deviceName,
    linuxDataFolderPath: newPath,
  );

  /// Turns the settings into JSON for `settings.json`.
  Map<String, Object?> toJson() => {
    'device_id': deviceId,
    'device_name': deviceName,
    'linux_data_folder_path': linuxDataFolderPath,
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
