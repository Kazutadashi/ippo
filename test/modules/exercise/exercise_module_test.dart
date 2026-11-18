// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the exercise module, from saving events to reading the log
/// back, with real files in temporary folders.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/exercise/exercise.dart';
import 'package:ippo/modules/exercise/exercise_actions.dart';
import 'package:ippo/modules/exercise/exercise_log.dart';
import 'package:ippo/modules/exercise/progression.dart';

const String day1 = '2026-11-16';
const String day2 = '2026-11-17';

/// A two-step squat ladder: 3 × 10 box squats, then 3 × 8 squats.
const List<StepDraft> squatDrafts = [
  StepDraft(
    exerciseId: null,
    exerciseName: 'Box squat',
    measuredIn: MeasuredIn.reps,
    targetSets: 3,
    targetPerSet: 10,
  ),
  StepDraft(
    exerciseId: null,
    exerciseName: 'Squat',
    measuredIn: MeasuredIn.reps,
    targetSets: 3,
    targetPerSet: 8,
  ),
];

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;
  late ExerciseActions actions;

  ExerciseLog currentLog() => ExerciseLog.fromEvents(appState.eventLog!.events);

  /// Reads the log again from the files on disk.
  Future<ExerciseLog> logFromDisk() async {
    await appState.reloadEvents();
    return currentLog();
  }

  Future<Progression> createSquatLadder() async {
    final id = await actions.saveProgressionFromDrafts(
      progressionId: null,
      name: 'Squat progression',
      drafts: squatDrafts,
      log: currentLog(),
    );
    return currentLog().progressions[id]!;
  }

  /// Logs sets of the current step of [progression] on [date].
  Future<void> logSets(
    Progression progression,
    String date,
    List<int> values,
  ) async {
    for (final value in values) {
      final log = currentLog();
      final stepNumber = log.currentStepNumber(progression);
      final exercise =
          log.exercises[progression.stepAt(stepNumber).exerciseId]!;
      await actions.recordSet(
        date: date,
        exercise: exercise,
        setNumber: log.setsOn(date, exercise.id).length + 1,
        value: value,
        weightKg: null,
        repsInReserve: null,
        progression: progression,
        stepNumber: stepNumber,
      );
    }
  }

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
    actions = ExerciseActions(appState);
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  test('saving a ladder creates its exercises and steps in order', () async {
    final ladder = await createSquatLadder();

    final log = await logFromDisk();
    final saved = log.progressions[ladder.id]!;
    expect(saved.name, 'Squat progression');
    expect(saved.steps, hasLength(2));
    expect(log.exercises[saved.steps[0].exerciseId]!.name, 'Box squat');
    expect(log.exercises[saved.steps[1].exerciseId]!.name, 'Squat');
    expect(saved.steps[0].describeTarget(), '3 × 10 reps');
    expect(log.currentStepNumber(saved), 1);
  });

  test('an exercise with the same name and unit is reused', () async {
    await actions.createExercise(
      name: 'box SQUAT',
      measuredIn: MeasuredIn.reps,
    );
    final ladder = await createSquatLadder();

    final log = currentLog();
    expect(log.exercises, hasLength(2));
    expect(log.exercises[ladder.steps[0].exerciseId]!.name, 'box SQUAT');
  });

  test('a set copies the step and target into the data', () async {
    final ladder = await createSquatLadder();
    await logSets(ladder, day1, [9]);

    final file = File(
      '${dataFolder.path}/events/${appState.settings!.deviceId}.jsonl',
    );
    final event =
        jsonDecode(file.readAsLinesSync().last) as Map<String, Object?>;
    expect(event['type'], 'set_recorded');
    expect(event['data'], {
      'exercise_id': ladder.steps[0].exerciseId,
      'date': day1,
      'set_number': 1,
      'reps': 9,
      'progression_id': ladder.id,
      'step_number': 1,
      'target_reps': 10,
    });
  });

  test('seconds-based exercises write seconds', () async {
    final event = await actions.createExercise(
      name: 'Plank',
      measuredIn: MeasuredIn.seconds,
    );
    final plank = currentLog().exercises[event.id]!;
    await actions.recordSet(
      date: day1,
      exercise: plank,
      setNumber: 1,
      value: 45,
      weightKg: 2.5,
      repsInReserve: null,
      progression: null,
      stepNumber: null,
    );

    final set = (await logFromDisk()).setsOn(day1, plank.id).single;
    expect(set.value, 45);
    expect(set.weightKg, 2.5);
    expect(set.progressionId, isNull);
  });

  test('moving up a step is saved, and new sets use the new step', () async {
    final ladder = await createSquatLadder();
    await logSets(ladder, day1, [10, 10, 10]);
    await actions.setProgressionStep(ladder.id, stepNumber: 2, date: day1);
    await logSets(ladder, day2, [6]);

    final log = await logFromDisk();
    expect(log.currentStepNumber(ladder), 2);
    final squatSet = log.setsOn(day2, ladder.steps[1].exerciseId).single;
    expect(squatSet.stepNumber, 2);
    expect(squatSet.targetPerSet, 8);
  });

  test('the level history rises through a step change', () async {
    final ladder = await createSquatLadder();
    await logSets(ladder, day1, [10, 10, 10]); // step 1 mastered: level 1
    await actions.setProgressionStep(ladder.id, stepNumber: 2, date: day1);
    await logSets(ladder, day2, [8, 4, 0]); // step 2, half way: 1.5

    final history = (await logFromDisk()).levelHistory(ladder);

    expect(history.map((point) => point.date), [day1, day2]);
    expect(history[0].value, closeTo(1.0, 1e-9));
    expect(history[1].value, closeTo(1.5, 1e-9));
  });

  test('changing a ladder later does not change past sets', () async {
    final ladder = await createSquatLadder();
    await logSets(ladder, day1, [7]);
    final log = currentLog();
    await actions.saveProgressionFromDrafts(
      progressionId: ladder.id,
      name: 'Squats',
      drafts: [
        StepDraft(
          exerciseId: ladder.steps[0].exerciseId,
          exerciseName: 'Box squat',
          measuredIn: MeasuredIn.reps,
          targetSets: 5,
          targetPerSet: 20,
        ),
      ],
      log: log,
    );

    final changedLog = await logFromDisk();
    final changed = changedLog.progressions[ladder.id]!;
    expect(changed.name, 'Squats');
    expect(changed.steps.single.targetPerSet, 20);
    final oldSet = changedLog.setsOn(day1, ladder.steps[0].exerciseId).single;
    expect(oldSet.targetPerSet, 10);
  });

  test('editing a step name renames its exercise', () async {
    final ladder = await createSquatLadder();
    await actions.saveProgressionFromDrafts(
      progressionId: ladder.id,
      name: 'Squat progression',
      drafts: [
        StepDraft(
          exerciseId: ladder.steps[0].exerciseId,
          exerciseName: 'Bench squat',
          measuredIn: MeasuredIn.reps,
          targetSets: 3,
          targetPerSet: 10,
        ),
      ],
      log: currentLog(),
    );

    final log = await logFromDisk();
    expect(log.exercises[ladder.steps[0].exerciseId]!.name, 'Bench squat');
  });

  test('changing, clearing and deleting a set', () async {
    final event = await actions.createExercise(
      name: 'Pull-up',
      measuredIn: MeasuredIn.reps,
    );
    final pullUp = currentLog().exercises[event.id]!;
    await actions.recordSet(
      date: day1,
      exercise: pullUp,
      setNumber: 1,
      value: 5,
      weightKg: 10,
      repsInReserve: 2,
      progression: null,
      stepNumber: null,
    );
    final set = currentLog().setsOn(day1, pullUp.id).single;

    await actions.changeSet(
      set,
      measuredIn: MeasuredIn.reps,
      value: 6,
      weightKg: null,
      repsInReserve: null,
    );
    final changed = (await logFromDisk()).setsOn(day1, pullUp.id).single;
    expect(changed.value, 6);
    expect(changed.weightKg, isNull);
    expect(changed.repsInReserve, isNull);

    await actions.deleteSet(set.id);
    expect((await logFromDisk()).setsOn(day1, pullUp.id), isEmpty);
    await actions.restoreSet(set.id);
    expect((await logFromDisk()).setsOn(day1, pullUp.id), hasLength(1));
  });

  test('exercises in a ladder are not listed as standalone', () async {
    await createSquatLadder();
    await actions.createExercise(name: 'Plank', measuredIn: MeasuredIn.seconds);

    final names = currentLog().standaloneExercises.map((e) => e.name);
    expect(names, ['Plank']);
  });

  test('a deleted ladder is hidden but its sets stay', () async {
    final ladder = await createSquatLadder();
    await logSets(ladder, day1, [5]);
    await actions.deleteProgression(ladder.id);

    final log = await logFromDisk();
    expect(log.activeProgressions, isEmpty);
    expect(log.setsOn(day1, ladder.steps[0].exerciseId), hasLength(1));
  });

  test('a saved step number beyond the ladder is kept in range', () async {
    final ladder = await createSquatLadder();
    await actions.setProgressionStep(ladder.id, stepNumber: 9, date: day1);

    expect((await logFromDisk()).currentStepNumber(ladder), 2);
  });

  test('invalid exercise data from other tools is counted', () async {
    await appState.writeEvent(
      module: 'exercise',
      type: 'exercise_created',
      data: {'name': 'No unit'},
    );
    await appState.writeEvent(
      module: 'exercise',
      type: 'progression_created',
      data: {'name': 'No steps', 'steps': []},
    );
    await appState.writeEvent(
      module: 'exercise',
      type: 'set_recorded',
      data: {'exercise_id': 'x', 'date': day1, 'set_number': 1},
    );

    final log = await logFromDisk();
    expect(log.invalidCount, 3);
    expect(log.exercises, isEmpty);
  });

  test('best set and total per day', () async {
    final event = await actions.createExercise(
      name: 'Push-up',
      measuredIn: MeasuredIn.reps,
    );
    final pushUp = currentLog().exercises[event.id]!;
    Future<void> logSet(String date, int reps) async {
      await actions.recordSet(
        date: date,
        exercise: pushUp,
        setNumber: currentLog().setsOn(date, pushUp.id).length + 1,
        value: reps,
        weightKg: null,
        repsInReserve: null,
        progression: null,
        stepNumber: null,
      );
    }

    await logSet(day1, 10);
    await logSet(day1, 5);
    await logSet(day2, 20);
    await logSet(day2, 20);

    final log = await logFromDisk();
    final best = log.dailyBest(pushUp.id);
    final totals = log.dailyTotals(pushUp.id);
    expect(best.map((point) => point.date), [day1, day2]);
    expect(best.map((point) => point.value), [10, 20]);
    expect(totals.map((point) => point.value), [15, 40]);
  });
}
