// SPDX-License-Identifier: GPL-3.0-or-later

/// The app-wide state shared by every screen: settings, the data folder,
/// and the merged event log.
library;

import 'package:material_ui/material_ui.dart';

import 'dates.dart';
import 'demo/demo_plan.dart';
import 'events/event.dart';
import 'events/event_log.dart';
import 'events/event_log_reader.dart';
import 'events/backup_and_clear.dart';
import 'events/folder_readme.dart';
import 'events/monthly_backup.dart';
import 'events/event_writer.dart';
import 'settings/app_settings.dart';
import 'storage/android_data_folder.dart';
import 'storage/data_folder.dart';
import 'storage/local_data_folder.dart';
import 'storage/memory_data_folder.dart';
import 'storage/settings_file.dart';
import 'storage/system_time_zone.dart';

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
    this.systemAccentColor,
  });

  /// Where this install's settings are saved.
  final SettingsFile settingsFile;

  /// Whether the app runs on Android (true) or Linux (false).
  final bool isAndroid;

  /// The device name used until the user picks one.
  final String defaultDeviceName;

  /// The phone's own accent color, or null if it has none. See
  /// `system_colors.dart`.
  final Color? systemAccentColor;

  // Values worked out from the event log, kept until the log changes.
  // See [derived].
  final Map<String, Object> _derivedValues = {};
  // The module each derived value was built from, by key.
  final Map<String, String> _derivedModules = {};
  EventLog? _derivedFrom;

  AppSettings? _settings;
  DataFolder? _dataFolder;
  String? _dataFolderDescription;
  EventWriter? _eventWriter;
  EventLog? _eventLog;
  String? _errorMessage;

  // The device's IANA time zone, written into each new event; null if
  // not known. Read again whenever the app comes back to the front, in
  // case the user traveled.
  String? _timeZone;
  bool _isLoading = true;

  // While the demo runs: the real data folder and what was read from it,
  // put aside, so leaving the demo brings them back exactly as they were.
  ({
    DataFolder? folder,
    String? description,
    EventWriter? writer,
    EventLog? log,
  })?
  _beforeDemo;

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

  // Why the data folder cannot be read right now, or null if it can.
  String? _folderProblem;

  /// Why the data folder cannot be reached right now (missing, on a
  /// drive that is not connected, or no longer allowed), or null when
  /// the last read worked. Screens show it on every tab, so a folder
  /// that went missing never looks like data that is gone. It clears by
  /// itself once a read works again.
  String? get folderProblem => _folderProblem;

  /// Returns a value worked out from the events by [build], such as a
  /// module's diary, building it only once per change of the event log.
  ///
  /// Every tab, and Home, ask for the same values whenever they redraw.
  /// Working them out once and sharing them keeps the app fast as the
  /// data grows over the years. [key] names the value, for example
  /// `food_diary`; each key must always be built the same way.
  ///
  /// [module] is the one module whose events the value is built from.
  /// When this device saves an event, only that module's values are
  /// built again: a habit ticked does not rebuild the food diary.
  T derived<T extends Object>(
    String key,
    T Function(List<Event> events) build, {
    required String module,
  }) {
    final eventLog = _eventLog;
    // The event log is replaced (never changed in place) whenever events
    // are read or written, so a different object means new data.
    if (!identical(eventLog, _derivedFrom)) {
      _derivedValues.clear();
      _derivedFrom = eventLog;
    }
    final known = _derivedValues[key];
    if (known is T) {
      return known;
    }
    final value = build(eventLog?.events ?? const []);
    _derivedValues[key] = value;
    _derivedModules[key] = module;
    return value;
  }

  /// Whether the demo is running: the app shows made-up data kept only in
  /// memory, and the real data folder is set aside, untouched.
  bool get isDemo => _beforeDemo != null;

  /// Starts the demo with [eventFileText], the made-up events (see
  /// `demo_plan.dart`).
  ///
  /// The data folder becomes a [MemoryDataFolder] holding them. Anything
  /// added, changed or deleted during the demo stays in memory, and is
  /// gone when the demo ends or the app closes. Settings such as the
  /// accent color are still saved as usual.
  Future<void> startDemo(String eventFileText) async {
    if (isDemo) {
      return;
    }
    _beforeDemo = (
      folder: _dataFolder,
      description: _dataFolderDescription,
      writer: _eventWriter,
      log: _eventLog,
    );
    _dataFolder = MemoryDataFolder({
      '$eventsFolderName/$demoDeviceId.jsonl': eventFileText,
    });
    _dataFolderDescription = 'Example data, kept only in memory';
    _eventLog = null;
    _createEventWriter();
    await reloadEvents();
  }

  /// Ends the demo: its data is thrown away, and the real data folder
  /// comes back as it was. Its events are read again, in case a sync
  /// changed them meanwhile.
  Future<void> endDemo() async {
    final before = _beforeDemo;
    if (before == null) {
      return;
    }
    _beforeDemo = null;
    _dataFolder = before.folder;
    _dataFolderDescription = before.description;
    _eventWriter = before.writer;
    _eventLog = before.log;
    notifyListeners();
    await reloadEvents();
  }

  // The day picked with a day bar, or null to follow today. One for
  // the whole app, so every tab shows the same day.
  DateTime? _pickedDay;

  /// The day the screens show, at local midnight: today, unless another
  /// day was picked with a day bar. Shared by every tab.
  DateTime get shownDay => _pickedDay ?? today();

  /// Shows [day] on every tab. Picking today means following today
  /// again, so the screens move on by themselves after midnight. A day
  /// after today is never shown: there is no data ahead.
  void showDay(DateTime day) {
    _pickedDay = day.isBefore(today()) ? day : null;
    notifyListeners();
  }

  /// Loads the settings and the data folder, then reads the events.
  ///
  /// On the very first run, it creates new settings with a new device id.
  /// Errors do not throw; they appear in [errorMessage].
  Future<void> load() async {
    _timeZone = await readSystemTimeZone();
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

  /// Reads all event files again, for example after a sync. Also makes
  /// this month's backup, the first time each month.
  Future<void> reloadEvents() async {
    _timeZone = await readSystemTimeZone();
    final dataFolder = _dataFolder;
    if (dataFolder == null) {
      return;
    }
    try {
      _eventLog = await readEventLog(dataFolder);
      _clearFolderProblem();
    } on DataFolderException catch (error) {
      _setFolderProblem('Could not read the data folder: ${error.message}');
    }
    notifyListeners();
    await _makeMonthlyBackup(dataFolder);
  }

  // The month (YYYY-MM) whose backup is known to be done, so the backup
  // folder is not looked at again on every reload.
  String? _backedUpMonth;

  Future<void> _makeMonthlyBackup(DataFolder dataFolder) async {
    final settings = _settings;
    final now = DateTime.now();
    final month = formatDate(now).substring(0, 7);
    // The demo's folder is only in memory: nothing to back up there.
    if (settings == null || month == _backedUpMonth || isDemo) {
      return;
    }
    try {
      await makeMonthlyBackup(
        dataFolder,
        deviceId: settings.deviceId,
        now: now,
      );
      // The folder note goes with the backup: both run once a month at
      // most, so the folder is not looked at on every reload.
      await writeFolderReadme(dataFolder);
      _backedUpMonth = month;
    } on DataFolderException catch (error) {
      _errorMessage = 'Could not make this month\'s backup: ${error.message}';
      notifyListeners();
    }
  }

  /// Copies every event file into a new folder under `backups/`. Returns
  /// that folder's path. Throws [DataFolderException] on failure.
  Future<String> backUpNow() {
    return backUpAllEvents(_requireDataFolder(), now: DateTime.now());
  }

  /// The backups that can be restored, newest first: see
  /// [listManualBackups].
  Future<List<String>> manualBackups() {
    return listManualBackups(_requireDataFolder());
  }

  /// Adds the events in [backupFolder] back into the event files, and
  /// shows them. Returns how many were added; nothing is replaced (see
  /// [restoreBackup]). Throws [DataFolderException] on failure.
  Future<int> restoreFrom(String backupFolder) async {
    final added = await restoreBackup(_requireDataFolder(), backupFolder);
    await reloadEvents();
    return added;
  }

  /// Deletes every event file, from every device, after a full backup,
  /// and shows the app empty. Returns the backup folder's path. Throws
  /// [DataFolderException] on failure; nothing is deleted unless the
  /// backup worked.
  Future<String> clearAllData() async {
    final backupFolder = await clearAllEvents(
      _requireDataFolder(),
      now: DateTime.now(),
    );
    await reloadEvents();
    return backupFolder;
  }

  DataFolder _requireDataFolder() {
    final dataFolder = _dataFolder;
    if (dataFolder == null) {
      throw DataFolderException('Please choose a data folder first.');
    }
    return dataFolder;
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
      final withEvent = eventLog.withEvent(event);
      _eventLog = withEvent;
      // Only the saving module's values change; the others are kept.
      if (identical(eventLog, _derivedFrom)) {
        _derivedFrom = withEvent;
        _derivedValues.removeWhere(
          (key, _) => _derivedModules[key] == event.module,
        );
      }
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

  /// Saves the accent color, written as `#RRGGBB`.
  Future<void> setAccentColor(String hexColor) => _changeDisplaySetting(
    (settings) => settings.copyWith(accentColor: hexColor),
  );

  /// Saves how times are shown: `24h` or `12h`.
  Future<void> setClockStyle(String clockStyle) => _changeDisplaySetting(
    (settings) => settings.copyWith(clockStyle: clockStyle),
  );

  /// Lists habits `added` (as they were added) or by `color`.
  Future<void> setHabitOrder(String order) =>
      _changeDisplaySetting((settings) => settings.copyWith(habitOrder: order));

  /// Shows measurements in `metric` or `imperial` units.
  Future<void> setUnits(String units) =>
      _changeDisplaySetting((settings) => settings.copyWith(units: units));

  /// Turns the true black dark mode on or off.
  Future<void> setTrueBlack(bool isOn) => _changeDisplaySetting(
    (settings) => settings.copyWith(usesTrueBlack: isOn),
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
      _setFolderProblem('The data folder $path cannot be found.');
      return;
    }
    _useLinuxFolder(path);
  }

  /// Tries the saved data folder again, after a folder problem: for a
  /// drive that is connected again, say. Errors appear in
  /// [folderProblem].
  Future<void> retryDataFolder() async {
    if (_dataFolder == null) {
      try {
        await _openSavedDataFolder();
      } on DataFolderException catch (error) {
        _setFolderProblem(error.message);
      }
    }
    if (_dataFolder == null) {
      notifyListeners();
      return;
    }
    await reloadEvents();
  }

  /// Records [problem] as the folder problem, and as the error Settings
  /// shows.
  void _setFolderProblem(String problem) {
    _folderProblem = problem;
    _errorMessage = problem;
  }

  /// Forgets the folder problem once the folder can be read again, and
  /// the error it set, but no other error.
  void _clearFolderProblem() {
    final problem = _folderProblem;
    if (problem == null) {
      return;
    }
    if (_errorMessage == problem) {
      _errorMessage = null;
    }
    _folderProblem = null;
  }

  void _useAndroidFolder(String folderUri) {
    // Choosing a real folder ends the demo, if it is running.
    _beforeDemo = null;
    _folderProblem = null;
    _dataFolder = AndroidDataFolder(folderUri);
    _dataFolderDescription = describeAndroidFolder(folderUri);
    _eventLog = null;
    _createEventWriter();
  }

  void _useLinuxFolder(String path) {
    // Choosing a real folder ends the demo, if it is running.
    _beforeDemo = null;
    _folderProblem = null;
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
      timeZone: () => _timeZone,
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
