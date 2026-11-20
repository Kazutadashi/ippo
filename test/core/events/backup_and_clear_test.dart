// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [backUpAllEvents] and [clearAllEvents]; restoring is in
/// `restore_backup_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/backup_and_clear.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

void main() {
  late Directory folder;
  late LocalDataFolder dataFolder;
  final now = DateTime(2026, 11, 19, 8, 5, 30);

  setUp(() async {
    folder = Directory.systemTemp.createTempSync('ippo_clear_');
    dataFolder = LocalDataFolder(folder.path);
    await dataFolder.appendToTextFile('events/phone.jsonl', 'a\n');
    await dataFolder.appendToTextFile('events/desktop.jsonl', 'b\n');
    await dataFolder.appendToTextFile('events/.sync.tmp', 'half');
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
  });

  String read(String path) => File('${folder.path}/$path').readAsStringSync();

  test('a backup copies every event file, from every device', () async {
    final backup = await backUpAllEvents(dataFolder, now: now);

    expect(backup, 'backups/manual-2026-11-19-080530');
    expect(read('$backup/phone.jsonl'), 'a\n');
    expect(read('$backup/desktop.jsonl'), 'b\n');
    // A sync tool's hidden file is not data.
    expect(File('${folder.path}/$backup/.sync.tmp').existsSync(), isFalse);
    // The originals are untouched.
    expect(read('events/phone.jsonl'), 'a\n');
  });

  test('clearing backs everything up, then deletes the event files', () async {
    final backup = await clearAllEvents(dataFolder, now: now);

    expect(read('$backup/phone.jsonl'), 'a\n');
    expect(read('$backup/desktop.jsonl'), 'b\n');
    expect(await dataFolder.listFileNames('events'), ['.sync.tmp']);
  });

  test('deleting never touches a folder', () async {
    Directory('${folder.path}/events/inner').createSync();
    await dataFolder.deleteFile('events/inner');
    expect(Directory('${folder.path}/events/inner').existsSync(), isTrue);
  });
}
