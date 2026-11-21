// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for body details, the BMR, the daily limit and the reference
/// amounts, with real files in temporary folders.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/body/body_actions.dart';
import 'package:ippo/modules/body/body_log.dart';
import 'package:ippo/modules/body/bmr.dart';
import 'package:ippo/modules/food/daily_references.dart';
import 'package:ippo/modules/food/food_actions.dart';
import 'package:ippo/modules/food/food_module.dart';
import 'package:ippo/modules/food/nutrients.dart';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;
  late AppState appState;
  late BodyActions actions;

  Future<BodyLog> logFromDisk() async {
    await appState.reloadEvents();
    return BodyLog.of(appState);
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
    actions = BodyActions(appState);
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  test('the BMR follows Mifflin-St Jeor', () {
    // 10 × 70 + 6.25 × 175 − 5 × 30 + 5 = 1648.75
    expect(
      basalMetabolicRate(
        sex: Sex.male,
        weightKg: 70,
        heightCm: 175,
        ageYears: 30,
      ),
      closeTo(1648.75, 0.001),
    );
    // The same, female: − 161 instead of + 5.
    expect(
      basalMetabolicRate(
        sex: Sex.female,
        weightKg: 70,
        heightCm: 175,
        ageYears: 30,
      ),
      closeTo(1482.75, 0.001),
    );
    expect(
      basalMetabolicRate(sex: null, weightKg: 70, heightCm: 175, ageYears: 30),
      isNull,
    );
  });

  test('profile, weights changed in place, and limits by date', () async {
    await actions.saveProfile(sex: Sex.female, birthYear: 1990, heightCm: 168);
    await actions.saveWeight(date: '2026-11-10', weightKg: 70, existing: null);
    var log = await logFromDisk();
    await actions.saveWeight(
      date: '2026-11-10',
      weightKg: 69.5,
      existing: log.weightOn('2026-11-10'),
    );
    await actions.setEnergyTarget(date: '2026-11-12', energyKcal: 1800);
    await actions.setEnergyTarget(date: '2026-11-15', energyKcal: null);

    log = await logFromDisk();
    expect(log.sex, Sex.female);
    expect(log.heightCm, 168);
    expect(log.weights.where((weight) => !weight.isDeleted).length, 1);
    expect(log.weightAsOf('2026-11-14'), 69.5);
    expect(log.weightAsOf('2026-11-01'), isNull);
    // A limit counts from its day; removing it does too.
    expect(log.energyTargetOn('2026-11-11'), isNull);
    expect(log.energyTargetOn('2026-11-13'), 1800);
    expect(log.energyTargetOn('2026-11-16'), isNull);
  });

  test('reference amounts scale with the limit and the weight', () {
    final standard = dailyReferences();
    expect(standard[energyKey], 2000);
    expect(standard['fat_g'], 70);
    expect(standard['proteins_g'], 50);

    final lower = dailyReferences(energyTarget: 1500, weightKg: 60);
    expect(lower[energyKey], 1500);
    expect(lower['fat_g'], closeTo(52.5, 0.001));
    expect(lower['proteins_g'], closeTo(49.8, 0.001));
    // Salt and vitamins do not depend on either.
    expect(lower['salt_g'], 6);
  });

  test('the Food tile shows the day against the limit', () async {
    final now = DateTime(2026, 11, 17, 15, 30);
    final date = formatDate(currentDay(now));
    await actions.setEnergyTarget(date: date, energyKcal: 2000);
    await FoodActions(appState).recordQuickEntry(
      date: date,
      time: null,
      name: 'Soup',
      nutrients: const Nutrients({'energy_kcal': 500}),
    );
    await appState.reloadEvents();

    final tile = const FoodModule().homeTile(appState, currentDay(now), now);
    expect(tile.value, '500 kcal');
    expect(tile.valueNote, 'of 2,000');
    expect(tile.rows.first.label, 'Left today');
    expect(tile.rows.first.value, '1,500 kcal');
  });

  test('own nutrient goals replace the references from their day on', () async {
    await actions.setNutrientTarget(
      date: '2026-11-10',
      nutrient: 'fat_g',
      amount: 60,
      kind: GoalKind.atMost,
    );
    await actions.setNutrientTarget(
      date: '2026-11-15',
      nutrient: 'proteins_g',
      amount: 140,
      kind: GoalKind.atLeast,
    );
    await actions.setNutrientTarget(
      date: '2026-11-20',
      nutrient: 'fat_g',
      amount: null,
      kind: GoalKind.atMost,
    );
    final log = await logFromDisk();
    expect(log.nutrientTargetOn('fat_g', '2026-11-09'), isNull);
    expect(log.nutrientTargetOn('fat_g', '2026-11-12')?.amount, 60);
    // Removed on the 20th: the reference applies again.
    expect(log.nutrientTargetOn('fat_g', '2026-11-20'), isNull);
    expect(dailyReferencesOn(log, '2026-11-12')['fat_g'], 60);
    expect(dailyReferencesOn(log, '2026-11-20')['fat_g'], 70);
    expect(dailyReferencesOn(log, '2026-11-16')['proteins_g'], 140);
    expect(
      log.nutrientTargetOn('proteins_g', '2026-11-16')?.kind,
      GoalKind.atLeast,
    );
  });
}
