// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the exercise screen shows a progression's step, today's
/// sets, and offers to move up once the target is reached.
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

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  /// Creates a one-step-done ladder and logs [values] for today.
  Future<AppState> setUpLadder(WidgetTester tester, List<int> values) async {
    final appState = AppState(
      settingsFile: SettingsFile(settingsFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    await tester.runAsync(() async {
      await appState.load();
      await appState.chooseLinuxDataFolder(dataFolder.path);
      final actions = ExerciseActions(appState);
      final progressionId = await actions.saveProgressionFromDrafts(
        progressionId: null,
        name: 'Squat progression',
        drafts: const [
          StepDraft(
            exerciseId: null,
            exerciseName: 'Box squat',
            measuredIn: MeasuredIn.reps,
            targetSets: 2,
            targetPerSet: 10,
          ),
          StepDraft(
            exerciseId: null,
            exerciseName: 'Squat',
            measuredIn: MeasuredIn.reps,
            targetSets: 2,
            targetPerSet: 8,
          ),
        ],
        log: ExerciseLog.fromEvents(appState.eventLog!.events),
      );
      final log = ExerciseLog.fromEvents(appState.eventLog!.events);
      final ladder = log.progressions[progressionId]!;
      final boxSquat = log.exercises[ladder.steps[0].exerciseId]!;
      for (var index = 0; index < values.length; index++) {
        await actions.recordSet(
          date: formatDate(DateTime.now()),
          exercise: boxSquat,
          setNumber: index + 1,
          value: values[index],
          weightKg: null,
          repsInReserve: null,
          progression: ladder,
          stepNumber: 1,
        );
      }
    });
    return appState;
  }

  testWidgets('shows the step and today\'s sets', (tester) async {
    final appState = await setUpLadder(tester, [10, 7]);

    await tester.pumpWidget(
      MaterialApp(home: ExerciseHomeScreen(appState: appState)),
    );

    expect(find.text('Squat progression'), findsOneWidget);
    expect(find.text('Step 1 of 2: Box squat'), findsOneWidget);
    expect(find.text('Target 2 × 10 reps'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('move up'), findsNothing);
  });

  testWidgets('offers to move up once the target is reached', (tester) async {
    final appState = await setUpLadder(tester, [10, 10]);

    await tester.pumpWidget(
      MaterialApp(home: ExerciseHomeScreen(appState: appState)),
    );

    expect(find.text('Target reached: move up to step 2'), findsOneWidget);
  });
}
