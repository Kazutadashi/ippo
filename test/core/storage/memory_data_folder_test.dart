// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [MemoryDataFolder].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/storage/data_folder.dart';
import 'package:ippo/core/storage/memory_data_folder.dart';

void main() {
  test('lists, reads, appends and deletes like a real folder', () async {
    final folder = MemoryDataFolder({
      'events/a.jsonl': 'one\n',
      'events/.hidden': 'x',
      'backups/manual-1/a.jsonl': 'old\n',
    });

    expect(await folder.listFileNames('events'), ['.hidden', 'a.jsonl']);
    expect(await folder.listFolderNames('backups'), ['manual-1']);
    expect(await folder.listFileNames('backups'), isEmpty);

    await folder.appendToTextFile('events/a.jsonl', 'two\n');
    await folder.appendToTextFile('events/b.jsonl', 'new\n');
    expect(await folder.readTextFile('events/a.jsonl'), 'one\ntwo\n');
    expect(await folder.readTextFile('events/b.jsonl'), 'new\n');

    // Hidden files are not counted, as on disk.
    expect(await folder.sizeInBytes('events'), 12);

    await folder.deleteFile('events/b.jsonl');
    expect(
      () => folder.readTextFile('events/b.jsonl'),
      throwsA(isA<DataFolderException>()),
    );
    expect(() => folder.readTextFile('../x'), throwsA(anything));
  });
}
