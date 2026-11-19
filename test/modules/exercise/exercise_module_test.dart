// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the exercise module, from saving events to reading the log
/// back, with real files in temporary folders.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/module.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/exercise/exercise.dart';
import 'package:ippo/modules/exercise/exercise_actions.dart';
import 'package:ippo/modules/exercise/exercise_log.dart';
import 'package:ippo/modules/exercise/exercise_module.dart';
import 'package:ippo/core/dates.dart';

const String day1 = '2026-11-16';
const String day2 = '2026-11-17';

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

  Future<Exercise> createExercise(String name, MeasuredIn measuredIn) async {
    final event = await actions.createExercise(
      name: name,
      measuredIn: measuredIn,
    );
    return currentLog().exercises[event.id]!;
  }

  Future<void> addSets(
    Exercise exercise,
    String date,
    int value,
    int setCount,
  ) {
    return actions.recordSets(
      date: date,
      exercise: exercise,
      value: value,
      setCount: setCount,
      log: currentLog(),
    );
  }

  /// The last line of this device's event file, as JSON.
  Map<String, Object?> lastWrittenEvent() {
    final file = File(
      '${dataFolder.path}/events/${appState.settings!.deviceId}.jsonl',
    );
    return jsonDecode(file.readAsLinesSync().last) as Map<String, Object?>;
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

  test('a new exercise is saved with a trimmed name', () async {
    final exercise = await createExercise(' Push-up ', MeasuredIn.reps);

    final saved = (await logFromDisk()).exercises[exercise.id]!;
    expect(saved.name, 'Push-up');
    expect(saved.measuredIn, MeasuredIn.reps);
  });

  test('"2 sets of 20" adds two numbered sets', () async {
    final pushUp = await createExercise('Push-up', MeasuredIn.reps);
    await addSets(pushUp, day1, 20, 2);

    final sets = (await logFromDisk()).setsOn(day1, pushUp.id);
    expect(sets.map((set) => set.value), [20, 20]);
    expect(sets.map((set) => set.setNumber), [1, 2]);
  });

  test('"10, then 5" keeps counting the day\'s sets', () async {
    final pushUp = await createExercise('Push-up', MeasuredIn.reps);
    await addSets(pushUp, day1, 10, 1);
    await addSets(pushUp, day1, 5, 1);
    await addSets(pushUp, day2, 12, 1);

    final log = await logFromDisk();
    final day1Sets = log.setsOn(day1, pushUp.id);
    expect(day1Sets.map((set) => set.value), [10, 5]);
    expect(day1Sets.map((set) => set.setNumber), [1, 2]);
    expect(log.setsOn(day2, pushUp.id).single.setNumber, 1);
  });

  test('a set is written exactly as the data format says', () async {
    final pushUp = await createExercise('Push-up', MeasuredIn.reps);
    await addSets(pushUp, day1, 9, 1);

    final event = lastWrittenEvent();
    expect(event['module'], 'exercise');
    expect(event['type'], 'set_recorded');
    expect(event['data'], {
      'exercise_id': pushUp.id,
      'date': day1,
      'set_number': 1,
      'reps': 9,
    });
  });

  test('seconds-based exercises write seconds', () async {
    final plank = await createExercise('Plank', MeasuredIn.seconds);
    await addSets(plank, day1, 45, 1);

    expect((lastWrittenEvent()['data'] as Map<String, Object?>)['seconds'], 45);
    expect((await logFromDisk()).setsOn(day1, plank.id).single.value, 45);
  });

  test('the last set is remembered as the starting value', () async {
    final pushUp = await createExercise('Push-up', MeasuredIn.reps);
    expect(currentLog().lastSetOf(pushUp.id), isNull);

    await addSets(pushUp, day1, 12, 1);
    await addSets(pushUp, day1, 8, 1);

    expect((await logFromDisk()).lastSetOf(pushUp.id)!.value, 8);
  });

  test('changing, clearing and deleting a set', () async {
    final pullUp = await createExercise('Pull-up', MeasuredIn.reps);
    await addSets(pullUp, day1, 5, 1);
    final set = currentLog().setsOn(day1, pullUp.id).single;

    await actions.changeSet(
      set,
      measuredIn: MeasuredIn.reps,
      value: 6,
      weightKg: 10,
      repsInReserve: 2,
    );
    var changed = (await logFromDisk()).setsOn(day1, pullUp.id).single;
    expect(changed.value, 6);
    expect(changed.weightKg, 10);
    expect(changed.repsInReserve, 2);

    await actions.changeSet(
      set,
      measuredIn: MeasuredIn.reps,
      value: 6,
      weightKg: null,
      repsInReserve: null,
    );
    changed = (await logFromDisk()).setsOn(day1, pullUp.id).single;
    expect(changed.weightKg, isNull);
    expect(changed.repsInReserve, isNull);

    await actions.deleteSet(set.id);
    expect((await logFromDisk()).setsOn(day1, pullUp.id), isEmpty);
    await actions.restoreSet(set.id);
    expect((await logFromDisk()).setsOn(day1, pullUp.id), hasLength(1));
  });

  test('renaming and deleting an exercise', () async {
    final pushUp = await createExercise('Push-up', MeasuredIn.reps);
    await addSets(pushUp, day1, 10, 1);

    await actions.renameExercise(pushUp.id, 'Knee push-up');
    expect((await logFromDisk()).exercises[pushUp.id]!.name, 'Knee push-up');

    await actions.deleteExercise(pushUp.id);
    final log = await logFromDisk();
    expect(log.activeExercises, isEmpty);
    expect(log.setsOn(day1, pushUp.id), hasLength(1));
  });

  test('exercises are listed in the order they were created', () async {
    await createExercise('Squat', MeasuredIn.reps);
    await createExercise('Plank', MeasuredIn.seconds);
    await createExercise('Dip', MeasuredIn.reps);

    final names = currentLog().activeExercises.map((exercise) => exercise.name);
    expect(names, ['Squat', 'Plank', 'Dip']);
  });

  test('unknown event types and fields are ignored', () async {
    // Events a newer version or another tool might write.
    final exercise = await createExercise('Box squat', MeasuredIn.reps);
    await appState.writeEvent(
      module: 'exercise',
      type: 'routine_created',
      data: {'name': 'Leg day'},
    );
    await appState.writeEvent(
      module: 'exercise',
      type: 'set_recorded',
      data: {
        'exercise_id': exercise.id,
        'date': day1,
        'set_number': 1,
        'reps': 8,
        'tempo': '3-1-1',
      },
    );

    final log = await logFromDisk();
    expect(log.invalidCount, 0);
    expect(log.activeExercises.single.name, 'Box squat');
    expect(log.setsOn(day1, exercise.id).single.value, 8);
  });

  test('invalid exercise data from other tools is counted', () async {
    await appState.writeEvent(
      module: 'exercise',
      type: 'exercise_created',
      data: {'name': 'No unit'},
    );
    await appState.writeEvent(
      module: 'exercise',
      type: 'set_recorded',
      data: {'exercise_id': 'x', 'date': day1, 'set_number': 1},
    );

    final log = await logFromDisk();
    expect(log.invalidCount, 2);
    expect(log.exercises, isEmpty);
  });

  test('home tile: the best set of each exercise done that day', () async {
    const module = ExerciseModule();
    final now = DateTime(2026, 11, 18, 20);
    final day = currentDay(now);
    expect(describeTiles(module.dayFacts(appState, day, now)), [
      'Exercise: – | No sets logged yet',
    ]);

    final pushUp = await createExercise('Push-up', MeasuredIn.reps);
    final plank = await createExercise('Plank', MeasuredIn.seconds);
    await createExercise('Squat', MeasuredIn.reps);
    await addSets(pushUp, '2026-11-16', 15, 1);
    expect(describeTiles(module.dayFacts(appState, day, now)), [
      'Exercise: – | Last workout 2 days ago',
    ]);

    await addSets(pushUp, '2026-11-18', 20, 1);
    await addSets(pushUp, '2026-11-18', 18, 1);
    await addSets(plank, '2026-11-18', 45, 1);
    expect(describeTiles(module.dayFacts(appState, day, now)), [
      'Exercise: best sets: 2 exercises | Push-up 20 reps, Plank 45 s',
    ]);
    expect(
      describeDetail(module.weekSummary(appState, day)!),
      'Workouts 2 days',
    );
  });
}

/// Writes a detail as `Label value`, or just the value without a label.
String describeDetail(TileDetail detail) =>
    detail.label == null ? detail.value : '${detail.label} ${detail.value}';

/// Writes home tiles as `Label: value | note or details`, for comparing.
List<String> describeTiles(List<TodayFact> facts) => [
  for (final fact in facts)
    '${fact.label}: ${fact.value} | '
        '${fact.note ?? fact.details.map(describeDetail).join(', ')}',
];
