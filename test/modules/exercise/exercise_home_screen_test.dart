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
          date: formatDate(DateTime.now()),
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

  testWidgets('shows each exercise with today\'s sets', (tester) async {
    await setUpPushUps(tester, [10, 7]);

    expect(find.text('Push-up'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '10'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '7'), findsOneWidget);
    // There is nothing about progressions or statistics.
    expect(find.textContaining('rogression'), findsNothing);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('the reps field starts at the last set', (tester) async {
    await setUpPushUps(tester, [10, 7]);

    final repsField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Reps'),
    );
    expect(repsField.controller!.text, '7');
  });

  testWidgets('quick add logs several sets at once', (tester) async {
    await setUpPushUps(tester, []);

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '20');
    await tester.enterText(find.widgetWithText(TextField, 'Sets'), '2');
    // Saving writes real files, so let it run outside the test clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.widgetWithText(ActionChip, '20'), findsNWidgets(2));
    final log = ExerciseLog.fromEvents(appState.eventLog!.events);
    final sets = log.setsOn(formatDate(DateTime.now()), pushUpId);
    expect(sets.map((set) => set.setNumber), [1, 2]);
  });

  testWidgets('too many sets at once are refused', (tester) async {
    await setUpPushUps(tester, []);

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '20');
    await tester.enterText(find.widgetWithText(TextField, 'Sets'), '22');
    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(find.text('Enter 1 to 10 sets at a time.'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
  });
}
