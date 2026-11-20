// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [AppState.startDemo] and [AppState.endDemo]: the demo never
/// touches the real data folder.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/memory_data_folder.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/all_modules.dart';
import 'package:ippo/modules/habits/habit_actions.dart';
import 'package:ippo/modules/habits/habit_log.dart';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;

  setUp(() async {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await appState.load();
    await appState.chooseLinuxDataFolder(dataFolder.path);
    await HabitActions(appState).createHabit('Read 10 pages');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  /// Every file in the real data folder, with its contents.
  Map<String, String> realFiles() => {
    for (final file in dataFolder.listSync(recursive: true).whereType<File>())
      file.path: file.readAsStringSync(),
  };

  test(
    'the demo shows made-up data and leaves the real folder alone',
    () async {
      final before = realFiles();

      await startDemo(appState);
      expect(appState.isDemo, isTrue);
      expect(appState.dataFolder, isA<MemoryDataFolder>());
      var habits = HabitLog.fromEvents(appState.eventLog!.events);
      expect(habits.habits, hasLength(5));

      // Things done during the demo stay in memory.
      await HabitActions(appState).createHabit('Stretch more');
      expect(realFiles(), before);

      await appState.endDemo();
      expect(appState.isDemo, isFalse);
      habits = HabitLog.fromEvents(appState.eventLog!.events);
      expect(habits.habits.values.map((habit) => habit.name), [
        'Read 10 pages',
      ]);
      expect(realFiles(), before);
    },
  );

  test('the demo works before a data folder is chosen', () async {
    final emptySettings = Directory.systemTemp.createTempSync('ippo_s_');
    addTearDown(() => emptySettings.deleteSync(recursive: true));
    final firstRun = AppState(
      settingsFile: SettingsFile(emptySettings.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await firstRun.load();
    expect(firstRun.dataFolder, isNull);

    await startDemo(firstRun);
    expect(firstRun.eventLog!.events, isNotEmpty);
    await firstRun.endDemo();
    expect(firstRun.dataFolder, isNull);
  });

  test('choosing a real folder ends the demo', () async {
    await startDemo(appState);
    await appState.chooseLinuxDataFolder(dataFolder.path);
    expect(appState.isDemo, isFalse);
  });
}
