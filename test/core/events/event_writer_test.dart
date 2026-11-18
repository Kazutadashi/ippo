// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [EventWriter], together with [readEventLog], using a real
/// temporary folder.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/event_log_reader.dart';
import 'package:ippo/core/events/event_writer.dart';
import 'package:ippo/core/storage/local_data_folder.dart';

const String phoneId = '019a8f3c-0000-7000-8000-000000000001';

void main() {
  late Directory temporaryFolder;
  late LocalDataFolder dataFolder;
  late DateTime clock;

  EventWriter makeWriter() => EventWriter(
    dataFolder: dataFolder,
    deviceId: phoneId,
    deviceName: 'my-phone',
    now: () => clock,
  );

  String eventFileText() =>
      File('${temporaryFolder.path}/events/$phoneId.jsonl').readAsStringSync();

  setUp(() {
    temporaryFolder = Directory.systemTemp.createTempSync('ippo_test_');
    dataFolder = LocalDataFolder(temporaryFolder.path);
    clock = DateTime.utc(2026, 11, 17, 12);
  });

  tearDown(() {
    temporaryFolder.deleteSync(recursive: true);
  });

  test('writes one line per event to events/<device id>.jsonl', () async {
    final writer = makeWriter();
    await writer.write(module: 'habits', type: 'a', data: {});
    await writer.write(module: 'habits', type: 'b', data: {});

    final lines = eventFileText().split('\n');
    expect(lines, hasLength(3)); // two lines, then the empty text after \n
    expect(lines.last, isEmpty);
    expect(writer.filePath, 'events/$phoneId.jsonl');
  });

  test('what is written reads back as the same events', () async {
    final writer = makeWriter();
    final written = await writer.write(
      module: 'habits',
      type: 'habit_entry_recorded',
      data: {'date': '2026-11-17', 'value': 12, 'note': '一歩'},
    );

    final log = await readEventLog(dataFolder, now: clock);

    expect(log.problems, isEmpty);
    final read = log.events.single;
    expect(read.toJsonLine(), written.toJsonLine());
    expect(read.recordedAtUtc, written.recordedAtUtc);
    expect(read.deviceId, phoneId);
    expect(read.data['note'], '一歩');
  });

  test('quick writes all arrive, in the order they were made', () async {
    final writer = makeWriter();
    final writes = [
      for (var number = 0; number < 20; number++)
        writer.write(module: 'habits', type: 'count', data: {'n': number}),
    ];
    await Future.wait(writes);

    final log = await readEventLog(dataFolder, now: clock);
    final numbers = log.events.map((event) => event.data['n']).toList();
    expect(numbers, [for (var number = 0; number < 20; number++) number]);
  });

  test('events in the same millisecond get increasing times', () async {
    // The clock is frozen, as if all three were made in one millisecond.
    final writer = makeWriter();
    final first = await writer.write(module: 'habits', type: 'a', data: {});
    final second = await writer.write(module: 'habits', type: 'b', data: {});
    final third = await writer.write(module: 'habits', type: 'c', data: {});

    expect(first.recordedAtUtc, clock);
    expect(second.recordedAtUtc, clock.add(const Duration(milliseconds: 1)));
    expect(third.recordedAtUtc, clock.add(const Duration(milliseconds: 2)));
  });

  test('a cut-off last line is kept apart from new events', () async {
    // Simulate the app being stopped in the middle of an earlier write.
    final eventsFolder = Directory('${temporaryFolder.path}/events')
      ..createSync();
    File('${eventsFolder.path}/$phoneId.jsonl')
        .writeAsStringSync('{"format_version":1,"id":"019a');

    await makeWriter().write(module: 'habits', type: 'a', data: {});

    final log = await readEventLog(dataFolder, now: clock);
    expect(log.events, hasLength(1));
    expect(log.problems.single.lineNumber, 1);
    // The damaged text itself is left exactly as it was.
    expect(eventFileText(), startsWith('{"format_version":1,"id":"019a\n'));
  });

  test('existing lines are never changed', () async {
    final writer = makeWriter();
    await writer.write(module: 'habits', type: 'a', data: {});
    final before = eventFileText();

    await makeWriter().write(module: 'habits', type: 'b', data: {});

    expect(eventFileText(), startsWith(before));
  });

  test('the reader skips hidden files and reads conflict copies', () async {
    await makeWriter().write(module: 'habits', type: 'a', data: {});
    final original = eventFileText();
    final eventsPath = '${temporaryFolder.path}/events';
    File('$eventsPath/.syncthing.partial.tmp').writeAsStringSync('garbage');
    File('$eventsPath/$phoneId.sync-conflict-20261117-120000-ABCDEFG.jsonl')
        .writeAsStringSync(original);

    final log = await readEventLog(dataFolder, now: clock);

    expect(log.events, hasLength(1));
    expect(log.problems, isEmpty);
  });

  test(
    'reading a data folder with no events folder gives an empty log',
    () async {
      final log = await readEventLog(dataFolder, now: clock);
      expect(log.events, isEmpty);
      expect(log.problems, isEmpty);
    },
  );

  test('a device id that is not a UUID is refused', () {
    expect(
      () => EventWriter(
        dataFolder: dataFolder,
        deviceId: '../escape',
        deviceName: 'my-phone',
      ),
      throwsArgumentError,
    );
  });
}
