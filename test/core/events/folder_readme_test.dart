// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [writeFolderReadme].
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/folder_readme.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

void main() {
  late Directory folder;
  late LocalDataFolder dataFolder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('ippo_readme_');
    dataFolder = LocalDataFolder(folder.path);
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
  });

  test('the note is written once, next to the events folder', () async {
    expect(await writeFolderReadme(dataFolder), isTrue);
    expect(await writeFolderReadme(dataFolder), isFalse);

    final note = File('${folder.path}/$folderReadmeName');
    expect(note.readAsStringSync(), folderReadmeText);
  });

  test('a note that is already there is left alone', () async {
    final note = File('${folder.path}/$folderReadmeName')
      ..writeAsStringSync('my own notes');

    expect(await writeFolderReadme(dataFolder), isFalse);
    expect(note.readAsStringSync(), 'my own notes');
  });
}
