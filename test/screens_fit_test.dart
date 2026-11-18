// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that every tab fits a narrow phone screen, with some data on
/// it, in light and dark mode. Anything too wide makes Flutter report an
/// overflow, which fails this test.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/main.dart';
import 'package:ippo/modules/exercise/exercise.dart';
import 'package:ippo/modules/exercise/exercise_actions.dart';
import 'package:ippo/modules/exercise/exercise_log.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/nutrients.dart';
import 'package:ippo/modules/sleep/sleep_actions.dart';
import 'package:ippo/modules/sleep/sleep_episode.dart';
import 'package:ippo/modules/sleep/sleep_times.dart';
import 'package:ippo/core/dates.dart';
import 'package:material_ui/material_ui.dart';

/// The tabs along the bottom, in order.
const List<String> tabNames = ['Home', 'Food', 'Exercise', 'Sleep', 'Settings'];

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  /// Fills the data folder with a little of everything, with long names
  /// on purpose.
  Future<void> addSampleData(AppState appState) async {
    final todayDate = DateTime.now();
    final day = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final date = formatDate(day);
    await FoodActions(appState).recordQuickEntry(
      date: date,
      time: null,
      name: 'A rather long name for a restaurant breakfast plate',
      nutrients: const Nutrients({
        'energy_kcal': 1234.5,
        'proteins_g': 56.7,
        'carbohydrates_g': 123.4,
        'fat_g': 45.6,
      }),
    );
    final exerciseEvent = await ExerciseActions(appState).createExercise(
      name: 'Single-leg squat to a low box, slow',
      measuredIn: MeasuredIn.reps,
    );
    final exercise = ExerciseLog.fromEvents(appState.eventLog!.events)
        .exercises[exerciseEvent.id]!;
    await ExerciseActions(appState).recordSets(
      date: date,
      exercise: exercise,
      value: 120,
      setCount: 8,
      log: ExerciseLog.fromEvents(appState.eventLog!.events),
    );
    await SleepActions(appState).recordSleep(
      day: day,
      kind: SleepKind.night,
      period: nightPeriod(day, const ClockTime(21, 15), const ClockTime(9, 0)),
    );
  }

  for (final themeMode in ['light', 'dark']) {
    testWidgets('every tab fits a narrow screen ($themeMode)', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final appState = AppState(
        settingsFile: SettingsFile(settingsFolder.path),
        isAndroid: false,
        defaultDeviceName: 'my-desktop',
      );
      await tester.runAsync(() async {
        await appState.load();
        await appState.chooseLinuxDataFolder(dataFolder.path);
        await appState.setThemeMode(themeMode);
        await addSampleData(appState);
      });
      await tester.pumpWidget(IppoApp(appState: appState));
      await tester.pump();

      for (final tab in tabNames) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'the $tab tab');
      }
    });
  }
}
