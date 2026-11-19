// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the exercise screen shows each exercise with today's sets,
/// and that the quick-add row logs sets.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/exercise/exercise.dart';
import 'package:ippo/modules/exercise/exercise_actions.dart';
import 'package:ippo/modules/exercise/exercise_log.dart';
import 'package:ippo/modules/exercise/screens/exercise_home_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;
  late String pushUpId;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  /// Sets up a push-up exercise with [todaysReps] already logged today.
  Future<void> setUpPushUps(WidgetTester tester, List<int> todaysReps) async {
    appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    // Real file access needs runAsync inside widget tests.
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
      final actions = ExerciseActions(appState);
      final event = await actions.createExercise(
        name: 'Push-up',
        measuredIn: MeasuredIn.reps,
      );
      pushUpId = event.id;
      for (final reps in todaysReps) {
        await actions.recordSets(
          date: formatDate(today()),
          exercise: ExerciseLog.fromEvents(appState.eventLog!.events)
              .exercises[pushUpId]!,
          value: reps,
          setCount: 1,
          log: ExerciseLog.fromEvents(appState.eventLog!.events),
        );
      }
    });
    await tester.pumpWidget(
      MaterialApp(home: ExerciseHomeScreen(appState: appState)),
    );
  }

  testWidgets('shows today\'s sets in numbered columns', (tester) async {
    await setUpPushUps(tester, [10, 7]);

    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
    // There is nothing about progressions or statistics.
    expect(find.textContaining('rogression'), findsNothing);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('the last session is shown under the day', (tester) async {
    await setUpPushUps(tester, []);
    await tester.runAsync(() async {
      final log = ExerciseLog.fromEvents(appState.eventLog!.events);
      await ExerciseActions(appState).recordSets(
        date: formatDate(addDays(today(), -1)),
        exercise: log.exercises[pushUpId]!,
        value: 12,
        setCount: 2,
        log: log,
      );
    });
    await tester.pump();

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('12'), findsNWidgets(2));
    // Once in the table, once in the day bar at the top.
    expect(find.text('Today'), findsNWidgets(2));
  });

  testWidgets('the reps field starts at the last set', (tester) async {
    await setUpPushUps(tester, [10, 7]);

    final repsField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Reps'),
    );
    expect(repsField.controller!.text, '7');
  });

  testWidgets('plus and minus change the reps', (tester) async {
    await setUpPushUps(tester, [10]);

    await tester.tap(find.byTooltip('More 1'));
    await tester.tap(find.byTooltip('More 1'));
    await tester.tap(find.byTooltip('Fewer 1'));
    await tester.pump();

    final repsField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Reps'),
    );
    expect(repsField.controller!.text, '11');
  });

  testWidgets('Add set logs one set with the typed reps', (tester) async {
    await setUpPushUps(tester, []);

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '20');
    // Saving writes real files, so let it run outside the test clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Add set'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final log = ExerciseLog.fromEvents(appState.eventLog!.events);
    final sets = log.setsOn(formatDate(today()), pushUpId);
    expect(sets.map((set) => set.value), [20]);
    expect(find.text('Set 1'), findsOneWidget);
  });
}
