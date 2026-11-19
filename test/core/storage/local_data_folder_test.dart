// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [LocalDataFolder] and [checkRelativePath].
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/storage/data_folder.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

void main() {
  late Directory temporaryFolder;
  late LocalDataFolder dataFolder;

  setUp(() {
    temporaryFolder = Directory.systemTemp.createTempSync('ippo_test_');
    dataFolder = LocalDataFolder(temporaryFolder.path);
  });

  tearDown(() {
    temporaryFolder.deleteSync(recursive: true);
  });

  test('appending creates missing folders and the file', () async {
    await dataFolder.appendToTextFile('events/my-device.jsonl', 'first\n');

    final text = await dataFolder.readTextFile('events/my-device.jsonl');
    expect(text, 'first\n');
  });

  test('appending adds to the end and keeps what was there', () async {
    await dataFolder.appendToTextFile('events/my-device.jsonl', 'first\n');
    await dataFolder.appendToTextFile('events/my-device.jsonl', 'second\n');

    final text = await dataFolder.readTextFile('events/my-device.jsonl');
    expect(text, 'first\nsecond\n');
  });

  test('text is stored as UTF-8', () async {
    await dataFolder.appendToTextFile('events/my-device.jsonl', '一歩 ✓\n');

    final bytes = File('${temporaryFolder.path}/events/my-device.jsonl')
        .readAsBytesSync();
    expect(bytes, [
      0xE4, 0xB8, 0x80, 0xE6, 0xAD, 0xA9, 0x20, 0xE2, 0x9C, 0x93, 0x0A, //
    ]);
  });

  test('listing returns sorted file names and skips folders', () async {
    await dataFolder.appendToTextFile('events/b-device.jsonl', 'x\n');
    await dataFolder.appendToTextFile('events/a-device.jsonl', 'x\n');
    await dataFolder.appendToTextFile('events/sub/c-device.jsonl', 'x\n');

    final names = await dataFolder.listFileNames('events');
    expect(names, ['a-device.jsonl', 'b-device.jsonl']);
  });

  test('listing a folder that does not exist returns nothing', () async {
    expect(await dataFolder.listFileNames('events'), isEmpty);
  });

  test('sizes count a file, or every file in a folder and below', () async {
    await dataFolder.appendToTextFile('events/a.jsonl', '12345');
    await dataFolder.appendToTextFile('backups/2026-11/a.jsonl', '123');
    await dataFolder.appendToTextFile('backups/b.jsonl', 'é'); // 2 bytes
    // A sync tool's hidden files are not counted.
    await dataFolder.appendToTextFile('events/.sync/state', 'xxxxxxxx');
    await dataFolder.appendToTextFile('events/.hidden-file', 'xxxxxxxx');

    expect(await dataFolder.sizeInBytes('events/a.jsonl'), 5);
    expect(await dataFolder.sizeInBytes('events'), 5);
    expect(await dataFolder.sizeInBytes('backups'), 5);
    expect(await dataFolder.sizeInBytes('nothing-here'), 0);
  });

  test('reading a missing file throws DataFolderException', () async {
    expect(
      () => dataFolder.readTextFile('events/missing.jsonl'),
      throwsA(isA<DataFolderException>()),
    );
  });

  group('paths that could leave the data folder are refused', () {
    const unsafePaths = [
      '',
      '/absolute/path',
      '../outside.jsonl',
      'events/../../outside.jsonl',
      'events/./file.jsonl',
      'events//file.jsonl',
      'events/',
      r'events\..\outside.jsonl',
    ];

    for (final path in unsafePaths) {
      test('"$path"', () {
        expect(
          () => checkRelativePath(path),
          throwsA(isA<DataFolderException>()),
        );
        expect(
          () => dataFolder.appendToTextFile(path, 'x'),
          throwsA(isA<DataFolderException>()),
        );
      });
    }
  });

  test('normal nested paths are accepted', () {
    checkRelativePath('events/my-device.jsonl');
    checkRelativePath('backups/my-device/2026-01.jsonl');
  });
}
