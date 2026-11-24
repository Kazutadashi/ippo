// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [AppState], run the Linux way with temporary folders.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/events/uuid_v7.dart';
import 'package:ippo/core/storage/settings_file.dart';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;

  AppState makeAppState() => AppState(
    settingsFile: SettingsFile(settingsFolder.path),
    isAndroid: false,
    defaultDeviceName: 'my-desktop',
  );

  Map<String, Object?> savedSettings() => jsonDecode(
    File('${settingsFolder.path}/settings.json').readAsStringSync(),
  ) as Map<String, Object?>;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  test('the first run creates and saves a new device id', () async {
    final appState = makeAppState();
    await appState.load();

    final settings = appState.settings!;
    expect(isValidUuid(settings.deviceId), isTrue);
    expect(settings.deviceName, 'my-desktop');
    expect(savedSettings()['device_id'], settings.deviceId);
    expect(appState.dataFolder, isNull);
    expect(appState.isLoading, isFalse);
  });

  test('later runs keep the same device id', () async {
    final firstRun = makeAppState();
    await firstRun.load();
    final secondRun = makeAppState();
    await secondRun.load();

    expect(secondRun.settings!.deviceId, firstRun.settings!.deviceId);
  });

  test('a chosen data folder is saved and used next time', () async {
    final firstRun = makeAppState();
    await firstRun.load();
    final problem = await firstRun.chooseLinuxDataFolder(dataFolder.path);

    expect(problem, isNull);
    expect(firstRun.dataFolder, isNotNull);
    expect(firstRun.eventWriter, isNotNull);
    expect(firstRun.eventLog!.events, isEmpty);

    final secondRun = makeAppState();
    await secondRun.load();
    expect(secondRun.dataFolderDescription, dataFolder.path);
  });

  test('a folder that does not exist is refused with a reason', () async {
    final appState = makeAppState();
    await appState.load();

    final missing = await appState.chooseLinuxDataFolder('/no/such/folder');
    final relative = await appState.chooseLinuxDataFolder('relative/path');

    expect(missing, contains('no folder'));
    expect(relative, contains('full path'));
    expect(appState.dataFolder, isNull);
  });

  test('written events show up after reading again', () async {
    final appState = makeAppState();
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);

    await appState.eventWriter!.write(module: 'habits', type: 'a', data: {});
    await appState.reloadEvents();

    expect(appState.eventLog!.events, hasLength(1));
    final lastSeen = appState.eventLog!.lastSeenByDevice;
    expect(lastSeen.keys.single, appState.settings!.deviceId);
  });

  test('renaming the device is saved and used for new events', () async {
    final appState = makeAppState();
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);

    expect(await appState.renameDevice('  my-laptop  '), isNull);
    final event = await appState.eventWriter!.write(
      module: 'habits',
      type: 'a',
      data: {},
    );

    expect(savedSettings()['device_name'], 'my-laptop');
    expect(event.deviceName, 'my-laptop');
  });

  test('an empty device name is refused', () async {
    final appState = makeAppState();
    await appState.load();

    expect(await appState.renameDevice('   '), isNotNull);
    expect(appState.settings!.deviceName, 'my-desktop');
  });

  test('damaged settings are reported and never replaced', () async {
    final settingsPath = '${settingsFolder.path}/settings.json';
    File(settingsPath).writeAsStringSync('{"device_id": "not-a-uuid"}');

    final appState = makeAppState();
    await appState.load();

    expect(appState.settings, isNull);
    expect(appState.errorMessage, contains('no valid device id'));
    expect(
      File(settingsPath).readAsStringSync(),
      '{"device_id": "not-a-uuid"}',
    );
  });

  test('a settings file that is not JSON is reported', () async {
    File('${settingsFolder.path}/settings.json').writeAsStringSync('{oops');

    final appState = makeAppState();
    await appState.load();

    expect(appState.settings, isNull);
    expect(appState.errorMessage, contains('damaged'));
  });

  test('a saved data folder that disappeared is reported', () async {
    // Settings that point to a folder which no longer exists, for example
    // on a drive that is not plugged in.
    File('${settingsFolder.path}/settings.json').writeAsStringSync(
      jsonEncode({
        'device_id': '019a8f3c-0000-7000-8000-000000000001',
        'device_name': 'my-desktop',
        'linux_data_folder_path': '${dataFolder.path}/gone',
      }),
    );

    final appState = makeAppState();
    await appState.load();

    expect(appState.dataFolder, isNull);
    expect(appState.errorMessage, contains('cannot be found'));
  });

  group('describeAndroidFolder', () {
    test('shows the path inside the storage', () {
      expect(
        describeAndroidFolder(
          'content://com.android.externalstorage.documents/tree/'
          'primary%3ADocuments%2FIppo',
        ),
        'Documents/Ippo',
      );
    });

    test('names the top level of the storage', () {
      expect(
        describeAndroidFolder(
          'content://com.android.externalstorage.documents/tree/primary%3A',
        ),
        '(top level of the storage)',
      );
    });

    test('shows unfamiliar URIs as they are', () {
      expect(describeAndroidFolder('content://other/x'), 'content://other/x');
    });
  });

  test(
    'a data folder that goes away is a folder problem until it is back',
    () async {
      final appState = makeAppState();
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
      expect(appState.folderProblem, isNull);

      dataFolder.deleteSync(recursive: true);
      await appState.reloadEvents();
      expect(appState.folderProblem, isNotNull);
      expect(appState.errorMessage, appState.folderProblem);
      // What was read before is still shown.
      expect(appState.dataFolder, isNotNull);

      dataFolder.createSync();
      await appState.retryDataFolder();
      expect(appState.folderProblem, isNull);
      expect(appState.errorMessage, isNull);
    },
  );

  test(
    'a saved data folder missing at start is said, and tried again',
    () async {
      final firstRun = makeAppState();
      await firstRun.load();
      await firstRun.chooseLinuxDataFolder(dataFolder.path);
      dataFolder.deleteSync(recursive: true);

      final secondRun = makeAppState();
      await secondRun.load();
      expect(secondRun.dataFolder, isNull);
      expect(secondRun.folderProblem, contains(dataFolder.path));

      await secondRun.retryDataFolder();
      expect(secondRun.folderProblem, isNotNull);

      dataFolder.createSync();
      await secondRun.retryDataFolder();
      expect(secondRun.dataFolder, isNotNull);
      expect(secondRun.folderProblem, isNull);
    },
  );

  test('saving an event rebuilds only its own module\'s values', () async {
    final appState = makeAppState();
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);
    var habitBuilds = 0;
    var foodBuilds = 0;
    int habits() => appState.derived('test_habits', (events) {
      habitBuilds++;
      return events.where((event) => event.module == 'habits').length;
    }, module: 'habits');
    int food() => appState.derived('test_food', (events) {
      foodBuilds++;
      return events.where((event) => event.module == 'food').length;
    }, module: 'food');
    expect((habits(), food()), (0, 0));

    await appState.writeEvent(
      module: 'habits',
      type: 'habit_created',
      data: {'name': 'Read 10 pages'},
    );
    expect((habits(), food()), (1, 0));
    expect((habitBuilds, foodBuilds), (2, 1));

    // Reading the folder again rebuilds everything.
    await appState.reloadEvents();
    expect((habits(), food()), (1, 0));
    expect((habitBuilds, foodBuilds), (3, 2));
  });
}
