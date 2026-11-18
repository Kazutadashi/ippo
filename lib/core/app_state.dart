// SPDX-License-Identifier: GPL-3.0-or-later

/// The app-wide state shared by every screen: settings, the data folder,
/// and the merged event log.
library;

import 'package:flutter/foundation.dart';

import 'events/event.dart';
import 'events/event_log.dart';
import 'events/event_log_reader.dart';
import 'events/event_writer.dart';
import 'settings/app_settings.dart';
import 'storage/android_data_folder.dart';
import 'storage/data_folder.dart';
import 'storage/local_data_folder.dart';
import 'storage/settings_file.dart';

/// Holds the app-wide state and tells listening screens when it changes.
///
/// Call [load] once when the app starts. Screens read the getters and
/// call the methods below; they never touch files themselves.
class AppState extends ChangeNotifier {
  /// Creates the app state.
  ///
  /// [isAndroid] chooses how the data folder is found. It is a parameter
  /// so tests can run the Linux way on any computer.
  /// [defaultDeviceName] is used when the app runs for the first time.
  AppState({
    required this.settingsFile,
    required this.isAndroid,
    required this.defaultDeviceName,
  });

  /// Where this install's settings are saved.
  final SettingsFile settingsFile;

  /// Whether the app runs on Android (true) or Linux (false).
  final bool isAndroid;

  /// The device name used until the user picks one.
  final String defaultDeviceName;

  AppSettings? _settings;
  DataFolder? _dataFolder;
  String? _dataFolderDescription;
  EventWriter? _eventWriter;
  EventLog? _eventLog;
  String? _errorMessage;
  bool _isLoading = true;

  /// True until [load] has finished.
  bool get isLoading => _isLoading;

  /// This install's settings, or null if they could not be loaded.
  AppSettings? get settings => _settings;

  /// The chosen data folder, or null if none is chosen yet.
  DataFolder? get dataFolder => _dataFolder;

  /// A short, readable description of the data folder for the screen,
  /// or null if none is chosen.
  String? get dataFolderDescription => _dataFolderDescription;

  /// Writes events to this device's file, or null without a data folder.
  EventWriter? get eventWriter => _eventWriter;

  /// All events from all devices, or null if not read yet.
  EventLog? get eventLog => _eventLog;

  /// The latest error to show the user, or null if all is well.
  String? get errorMessage => _errorMessage;

  /// Loads the settings and the data folder, then reads the events.
  ///
  /// On the very first run, it creates new settings with a new device id.
  /// Errors do not throw; they appear in [errorMessage].
  Future<void> load() async {
    try {
      final savedJson = await settingsFile.read();
      if (savedJson == null) {
        _settings = AppSettings.createNew(defaultDeviceName);
        await settingsFile.write(_settings!.toJson());
      } else {
        _settings = AppSettings.fromJson(
          savedJson,
          defaultDeviceName: defaultDeviceName,
        );
        if (_settings == null) {
          // Never replace damaged settings: the device id in them names
          // this device's event file. Let the user look at the file.
          _errorMessage =
              'The settings file has no valid device id. '
              'Please check ${settingsFile.folderPath}/$settingsFileName.';
        }
      }
      await _openSavedDataFolder();
    } on DataFolderException catch (error) {
      _errorMessage = error.message;
    }
    _isLoading = false;
    notifyListeners();
    await reloadEvents();
  }

  /// Reads all event files again, for example after a sync.
  Future<void> reloadEvents() async {
    final dataFolder = _dataFolder;
    if (dataFolder == null) {
      return;
    }
    try {
      _eventLog = await readEventLog(dataFolder);
    } on DataFolderException catch (error) {
      _errorMessage = 'Could not read the data folder: ${error.message}';
    }
    notifyListeners();
  }

  /// Writes a new event to this device's file and adds it to [eventLog].
  ///
  /// Modules call this to save anything. Listening screens are told
  /// about the change. Throws [DataFolderException] if no data folder is
  /// chosen or the event cannot be saved; nothing is saved then.
  Future<Event> writeEvent({
    required String module,
    required String type,
    required Map<String, Object?> data,
  }) async {
    final writer = _eventWriter;
    if (writer == null) {
      throw DataFolderException('Please choose a data folder first.');
    }
    final event = await writer.write(module: module, type: type, data: data);
    final eventLog = _eventLog;
    if (eventLog == null) {
      await reloadEvents();
    } else {
      _eventLog = eventLog.withEvent(event);
      notifyListeners();
    }
    return event;
  }

  /// Opens Android's folder picker and switches to the chosen folder.
  ///
  /// Does nothing if the user cancels. Errors appear in [errorMessage].
  Future<void> chooseAndroidDataFolder() async {
    try {
      final folderUri = await pickAndroidFolder();
      if (folderUri == null) {
        return;
      }
      _useAndroidFolder(folderUri);
      _errorMessage = null;
    } on DataFolderException catch (error) {
      _errorMessage = error.message;
    }
    notifyListeners();
    await reloadEvents();
  }

  /// Switches to the Linux data folder at [path] and saves the choice.
  ///
  /// Returns null on success, or a message explaining why [path] cannot
  /// be used.
  Future<String?> chooseLinuxDataFolder(String path) async {
    final settings = _settings;
    if (settings == null) {
      return 'Settings are not loaded.';
    }
    final trimmedPath = path.trim();
    final problem = LocalDataFolder.checkFolderPath(trimmedPath);
    if (problem != null) {
      return problem;
    }
    final saveProblem = await _saveSettings(
      settings.copyWith(linuxDataFolderPath: trimmedPath),
    );
    if (saveProblem != null) {
      return saveProblem;
    }
    _useLinuxFolder(trimmedPath);
    _errorMessage = null;
    notifyListeners();
    await reloadEvents();
    return null;
  }

  /// Renames this device and saves the new name.
  ///
  /// Returns null on success, or a message explaining what is wrong.
  /// Events written earlier keep the old name; new ones use the new name.
  Future<String?> renameDevice(String newName) async {
    final settings = _settings;
    if (settings == null) {
      return 'Settings are not loaded.';
    }
    final trimmedName = newName.trim();
    final problem = checkDeviceName(trimmedName);
    if (problem != null) {
      return problem;
    }
    final saveProblem = await _saveSettings(
      settings.copyWith(deviceName: trimmedName),
    );
    if (saveProblem != null) {
      return saveProblem;
    }
    _createEventWriter();
    notifyListeners();
    return null;
  }

  /// Saves the theme mode: `system`, `light` or `dark`.
  Future<void> setThemeMode(String themeMode) => _changeDisplaySetting(
    (settings) => settings.copyWith(themeMode: themeMode),
  );

  /// Saves the accent colour, written as `#RRGGBB`.
  Future<void> setAccentColor(String hexColor) => _changeDisplaySetting(
    (settings) => settings.copyWith(accentColor: hexColor),
  );

  /// Remembers which screen is open (a module's name, or `settings`), so
  /// the app opens there next time.
  Future<void> rememberScreen(String screenName) => _changeDisplaySetting(
    (settings) => settings.copyWith(lastScreen: screenName),
  );

  /// Applies [change] to the settings, saves them, and tells listening
  /// screens. A failure is shown through [errorMessage].
  Future<void> _changeDisplaySetting(
    AppSettings Function(AppSettings settings) change,
  ) async {
    final settings = _settings;
    if (settings == null) {
      return;
    }
    final problem = await _saveSettings(change(settings));
    if (problem != null) {
      _errorMessage = problem;
    }
    notifyListeners();
  }

  /// Writes [newSettings] to the settings file and uses them.
  ///
  /// Returns null on success, or a message explaining the failure; the
  /// old settings stay in use then.
  Future<String?> _saveSettings(AppSettings newSettings) async {
    try {
      await settingsFile.write(newSettings.toJson());
    } on DataFolderException catch (error) {
      return error.message;
    }
    _settings = newSettings;
    return null;
  }

  Future<void> _openSavedDataFolder() async {
    if (isAndroid) {
      final folderUri = await savedAndroidFolder();
      if (folderUri != null) {
        _useAndroidFolder(folderUri);
      }
      return;
    }
    final path = _settings?.linuxDataFolderPath;
    if (path == null) {
      return;
    }
    if (LocalDataFolder.checkFolderPath(path) != null) {
      // The folder may be on a drive that is not connected right now.
      _errorMessage = 'The data folder $path cannot be found.';
      return;
    }
    _useLinuxFolder(path);
  }

  void _useAndroidFolder(String folderUri) {
    _dataFolder = AndroidDataFolder(folderUri);
    _dataFolderDescription = describeAndroidFolder(folderUri);
    _eventLog = null;
    _createEventWriter();
  }

  void _useLinuxFolder(String path) {
    _dataFolder = LocalDataFolder(path);
    _dataFolderDescription = path;
    _eventLog = null;
    _createEventWriter();
  }

  void _createEventWriter() {
    final dataFolder = _dataFolder;
    final settings = _settings;
    if (dataFolder == null || settings == null) {
      _eventWriter = null;
      return;
    }
    _eventWriter = EventWriter(
      dataFolder: dataFolder,
      deviceId: settings.deviceId,
      deviceName: settings.deviceName,
    );
  }
}

/// Turns an Android folder URI into something readable.
///
/// For example
/// `content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FIppo`
/// becomes `Documents/Ippo`. Unfamiliar URIs are shown as they are.
String describeAndroidFolder(String folderUri) {
  const marker = '/tree/';
  final markerIndex = folderUri.indexOf(marker);
  if (markerIndex < 0) {
    return folderUri;
  }
  final decoded = Uri.decodeComponent(
    folderUri.substring(markerIndex + marker.length),
  );
  // "primary:Documents/Ippo" means internal storage, Documents/Ippo.
  final colonIndex = decoded.indexOf(':');
  final path = colonIndex < 0 ? decoded : decoded.substring(colonIndex + 1);
  return path.isEmpty ? '(top level of the storage)' : path;
}
