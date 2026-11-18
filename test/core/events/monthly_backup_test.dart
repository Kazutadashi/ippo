// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [makeMonthlyBackup].
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/monthly_backup.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

const String deviceId = '019a8f3c-0000-7000-8000-000000000001';

void main() {
  late Directory folder;
  late LocalDataFolder dataFolder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('ippo_backup_');
    dataFolder = LocalDataFolder(folder.path);
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
  });

  Future<bool> backUp(DateTime now) =>
      makeMonthlyBackup(dataFolder, deviceId: deviceId, now: now);

  List<String> backupNames() {
    final backups = Directory('${folder.path}/backups/$deviceId');
    if (!backups.existsSync()) {
      return [];
    }
    return backups.listSync().map((file) => file.uri.pathSegments.last).toList()
      ..sort();
  }

  test('nothing is made before the device has events', () async {
    expect(await backUp(DateTime(2026, 11, 18)), isFalse);
    expect(backupNames(), isEmpty);
  });

  test('the first time in a month, the event file is copied', () async {
    await dataFolder.appendToTextFile('events/$deviceId.jsonl', 'a\nb\n');

    expect(await backUp(DateTime(2026, 11, 18)), isTrue);

    expect(backupNames(), ['2026-11-18.jsonl']);
    final copy = File('${folder.path}/backups/$deviceId/2026-11-18.jsonl');
    expect(copy.readAsStringSync(), 'a\nb\n');
  });

  test('only one backup a month, then one in the next month', () async {
    await dataFolder.appendToTextFile('events/$deviceId.jsonl', 'a\n');

    expect(await backUp(DateTime(2026, 11, 18)), isTrue);
    await dataFolder.appendToTextFile('events/$deviceId.jsonl', 'b\n');
    expect(await backUp(DateTime(2026, 11, 30)), isFalse);
    expect(await backUp(DateTime(2026, 12, 1)), isTrue);

    expect(backupNames(), ['2026-11-18.jsonl', '2026-12-01.jsonl']);
    // A backup is never changed after it is made.
    final first = File('${folder.path}/backups/$deviceId/2026-11-18.jsonl');
    expect(first.readAsStringSync(), 'a\n');
  });

  test('backups are not read as events', () async {
    await dataFolder.appendToTextFile('events/$deviceId.jsonl', 'a\n');
    await backUp(DateTime(2026, 11, 18));

    expect(await dataFolder.listFileNames('events'), ['$deviceId.jsonl']);
  });
}
