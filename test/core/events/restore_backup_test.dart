// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [listManualBackups] and [restoreBackup].
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/backup_and_clear.dart';
import 'package:ippo/core/settings/backup_section.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

void main() {
  late Directory folder;
  late LocalDataFolder dataFolder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('ippo_restore_');
    dataFolder = LocalDataFolder(folder.path);
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
  });

  String read(String path) => File('${folder.path}/$path').readAsStringSync();

  /// A minimal event line; restoring only looks at the id.
  String line(String id) => '{"id":"$id","type":"x"}\n';

  test('lists the manual backups, newest first', () async {
    await dataFolder.appendToTextFile('backups/manual-2026-01-02-030405/a', '');
    await dataFolder.appendToTextFile('backups/manual-2026-03-01-120000/a', '');
    // A monthly snapshot folder and a hidden folder are not listed.
    await dataFolder.appendToTextFile('backups/monthly/a', '');
    await dataFolder.appendToTextFile('backups/.trash/a', '');

    expect(await listManualBackups(dataFolder), [
      'backups/manual-2026-03-01-120000',
      'backups/manual-2026-01-02-030405',
    ]);
  });

  test('no backups folder means no backups', () async {
    expect(await listManualBackups(dataFolder), isEmpty);
  });

  test('adds back only the missing events, to the same file', () async {
    const backup = 'backups/manual-2026-01-02-030405';
    await dataFolder.appendToTextFile(
      '$backup/phone.jsonl',
      '${line('1')}${line('2')}not json\n',
    );
    await dataFolder.appendToTextFile('$backup/desktop.jsonl', line('9'));
    await dataFolder.appendToTextFile('$backup/.sync.tmp', line('8'));
    // Since the backup, the phone kept event 2 and wrote event 3.
    await dataFolder.appendToTextFile(
      'events/phone.jsonl',
      line('2') + line('3'),
    );

    final added = await restoreBackup(dataFolder, backup);

    expect(added, 2);
    // Event 3 stays; event 1 is added after it; event 2 is not doubled.
    expect(read('events/phone.jsonl'), line('2') + line('3') + line('1'));
    // A file missing from events/ is made again.
    expect(read('events/desktop.jsonl'), line('9'));
    expect(File('${folder.path}/events/.sync.tmp').existsSync(), isFalse);
    // The backup itself is untouched.
    expect(read('$backup/desktop.jsonl'), line('9'));
  });

  test('restoring twice adds nothing the second time', () async {
    const backup = 'backups/manual-2026-01-02-030405';
    await dataFolder.appendToTextFile('$backup/phone.jsonl', line('1'));

    expect(await restoreBackup(dataFolder, backup), 1);
    expect(await restoreBackup(dataFolder, backup), 0);
    expect(read('events/phone.jsonl'), line('1'));
  });

  test('an unfinished last line is ended before adding', () async {
    const backup = 'backups/manual-2026-01-02-030405';
    await dataFolder.appendToTextFile('$backup/phone.jsonl', line('1'));
    await dataFolder.appendToTextFile('events/phone.jsonl', '{"id":"2"}');

    await restoreBackup(dataFolder, backup);

    expect(read('events/phone.jsonl'), '{"id":"2"}\n${line('1')}');
  });

  test('backup names read as a date and time', () {
    expect(
      backupLabel('backups/manual-2026-01-02-030405'),
      '2026-01-02 at 03:04:05',
    );
    expect(backupLabel('backups/odd-name'), 'odd-name');
  });
}
