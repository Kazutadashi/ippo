// SPDX-License-Identifier: GPL-3.0-or-later

/// The app's own settings file, kept outside the data folder.
///
/// A few things belong to one install of the app, not to the shared
/// data: this device's id and name, and (on Linux) where the data folder
/// is. They live in `settings.json` in a private folder:
///
/// - Android: the app's private files folder, which no other app can
///   read.
/// - Linux: `$XDG_CONFIG_HOME/ippo/`, or `~/.config/ippo/` if
///   `XDG_CONFIG_HOME` is not set, as the XDG standard says.
///
/// This is the only file Ippo reads or writes outside the data folder.
library;

import 'dart:convert';
import 'dart:io';

import 'android_data_folder.dart';
import 'data_folder.dart';

/// The settings file's name inside its folder.
const String settingsFileName = 'settings.json';

/// Reads and writes `settings.json` in [folderPath].
class SettingsFile {
  /// Creates access to the settings file in [folderPath]. Tests use a
  /// temporary folder; the app uses [SettingsFile.forThisPlatform].
  SettingsFile(this.folderPath);

  /// The folder that holds the settings file.
  final String folderPath;

  /// Finds the settings folder for the platform the app is running on.
  ///
  /// Throws [DataFolderException] if no suitable folder can be found.
  static Future<SettingsFile> forThisPlatform() async {
    if (Platform.isAndroid) {
      return SettingsFile(await androidPrivateFolderPath());
    }
    return SettingsFile(_linuxSettingsFolderPath());
  }

  String get _filePath => '$folderPath/$settingsFileName';

  /// Returns the saved settings, or null if there are none yet (the
  /// first time the app runs).
  ///
  /// Throws [DataFolderException] if the file exists but cannot be read
  /// or is not a JSON object. The file is then left untouched, so a
  /// damaged file is never silently replaced.
  Future<Map<String, Object?>?> read() async {
    final file = File(_filePath);
    if (!file.existsSync()) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString(encoding: utf8));
    } on FileSystemException catch (error) {
      throw DataFolderException('Could not read settings: ${error.message}');
    } on FormatException {
      throw DataFolderException('The settings file $_filePath is damaged.');
    }
    if (decoded is! Map<String, Object?>) {
      throw DataFolderException('The settings file $_filePath is damaged.');
    }
    return decoded;
  }

  /// Saves [settings], replacing the previous settings.
  ///
  /// The new settings are first written to a temporary file, which then
  /// replaces the old one in a single step. So if the app stops halfway,
  /// the old settings are still intact. Throws [DataFolderException] on
  /// failure.
  Future<void> write(Map<String, Object?> settings) async {
    final temporaryFile = File('$_filePath.tmp');
    try {
      await Directory(folderPath).create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await temporaryFile.writeAsString(
        '${encoder.convert(settings)}\n',
        encoding: utf8,
        flush: true,
      );
      await temporaryFile.rename(_filePath);
    } on FileSystemException catch (error) {
      throw DataFolderException('Could not save settings: ${error.message}');
    }
  }
}

/// Finds the settings folder on Linux, following the XDG standard.
String _linuxSettingsFolderPath() {
  final environment = Platform.environment;
  final configHome = environment['XDG_CONFIG_HOME'];
  if (configHome != null && configHome.startsWith('/')) {
    return '$configHome/ippo';
  }
  final home = environment['HOME'];
  if (home == null || !home.startsWith('/')) {
    throw DataFolderException(
      'Cannot find a folder for settings: HOME is not set.',
    );
  }
  return '$home/.config/ippo';
}
