// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for measuring the data folder and writing sizes.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/data_usage.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

void main() {
  test('sizes are written as Android does, with 1000 bytes to a kB', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(830), '830 B');
    expect(formatBytes(1000), '1.0 kB');
    expect(formatBytes(12345), '12 kB');
    expect(formatBytes(4600000), '4.6 MB');
    expect(formatBytes(1200000000), '1.2 GB');
  });

  test('events and backups are measured apart', () async {
    final folder = Directory.systemTemp.createTempSync('ippo_usage_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final dataFolder = LocalDataFolder(folder.path);
    await dataFolder.appendToTextFile('events/my-phone.jsonl', '1234');
    await dataFolder.appendToTextFile('backups/manual-x/my-phone.jsonl', '12');
    await dataFolder.appendToTextFile('README.txt', 'not counted');

    final usage = await measureDataUsage(dataFolder);
    expect(usage.eventBytes, 4);
    expect(usage.backupBytes, 2);
    expect(usage.totalBytes, 6);
  });
}
