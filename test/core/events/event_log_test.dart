// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for reading event files and merging them into one log.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/event_file_parser.dart';
import 'package:ippo/core/events/event_log.dart';

const String phoneId = '019a8f3c-0000-7000-8000-000000000001';
const String desktopId = '019a8f3c-0000-7000-8000-000000000002';

/// The moment used as "now" in these tests.
final DateTime testNow = DateTime.utc(2026, 11, 18, 12);

/// Builds one event line. [number] makes the id unique.
String eventLine({
  required int number,
  required String recordedAt,
  String deviceId = phoneId,
  String deviceName = 'my-phone',
  int formatVersion = 1,
  Map<String, Object?> data = const {},
}) {
  final idEnd = number.toString().padLeft(12, '0');
  return jsonEncode({
    'format_version': formatVersion,
    'id': '019a8f3c-1111-7000-8000-$idEnd',
    'recorded_at': recordedAt,
    'device_id': deviceId,
    'device_name': deviceName,
    'module': 'habits',
    'type': 'habit_entry_recorded',
    'data': data,
  });
}

/// The last 12 digits of each event's id, as numbers, in log order.
List<int> eventNumbers(EventLog log) =>
    log.events.map((event) => int.parse(event.id.substring(24))).toList();

void main() {
  group('parseEventFile', () {
    test('reads every valid line in order', () {
      final text =
          '${eventLine(number: 1, recordedAt: '2026-11-17T08:00:00.000+00:00')}\n'
          '${eventLine(number: 2, recordedAt: '2026-11-17T09:00:00.000+00:00')}\n';

      final parsed = parseEventFile('$phoneId.jsonl', text);

      expect(parsed.events, hasLength(2));
      expect(parsed.problems, isEmpty);
      expect(parsed.fileName, '$phoneId.jsonl');
    });

    test('skips blank lines and Windows line endings quietly', () {
      final line = eventLine(
        number: 1,
        recordedAt: '2026-11-17T08:00:00.000+00:00',
      );
      final parsed = parseEventFile('a.jsonl', '\n$line\r\n\n   \n');

      expect(parsed.events, hasLength(1));
      expect(parsed.problems, isEmpty);
    });

    test('skips a damaged line, reports it, and keeps the rest', () {
      final good1 = eventLine(
        number: 1,
        recordedAt: '2026-11-17T08:00:00.000+00:00',
      );
      final good2 = eventLine(
        number: 2,
        recordedAt: '2026-11-17T09:00:00.000+00:00',
      );
      // A line cut off in the middle of a write, then a fresh line.
      final cutOff = good2.substring(0, 40);
      final parsed = parseEventFile('a.jsonl', '$good1\n$cutOff\n$good2\n');

      expect(parsed.events, hasLength(2));
      expect(parsed.problems, hasLength(1));
      expect(parsed.problems.single.lineNumber, 2);
      expect(parsed.problems.single.fileName, 'a.jsonl');
      expect(parsed.problems.single.reason, 'not valid JSON');
    });

    test('an empty file has no events and no problems', () {
      final parsed = parseEventFile('a.jsonl', '');
      expect(parsed.events, isEmpty);
      expect(parsed.problems, isEmpty);
    });
  });

  group('buildEventLog', () {
    test('merges files from several devices, ordered by moment', () {
      final phone = parseEventFile(
        '$phoneId.jsonl',
        '${eventLine(number: 1, recordedAt: '2026-11-17T08:00:00.000+00:00')}\n'
            '${eventLine(number: 3, recordedAt: '2026-11-17T10:00:00.000+00:00')}\n',
      );
      final desktop = parseEventFile(
        '$desktopId.jsonl',
        '${eventLine(number: 2, recordedAt: '2026-11-17T09:00:00.000+00:00', deviceId: desktopId)}\n',
      );

      final log = buildEventLog([phone, desktop], now: testNow);

      expect(eventNumbers(log), [1, 2, 3]);
    });

    test('compares exact moments, not local clock times', () {
      // 08:00 in UTC+9 is 23:00 the day before in UTC, so it comes first,
      // even though its local clock time looks later.
      final text =
          '${eventLine(number: 1, recordedAt: '2026-11-17T01:00:00.000+00:00')}\n'
          '${eventLine(number: 2, recordedAt: '2026-11-17T08:00:00.000+09:00')}\n';

      final log = buildEventLog([parseEventFile('a', text)], now: testNow);

      expect(eventNumbers(log), [2, 1]);
    });

    test('events at the same moment are ordered by id', () {
      const sameMoment = '2026-11-17T08:00:00.000+00:00';
      final text =
          '${eventLine(number: 9, recordedAt: sameMoment)}\n'
          '${eventLine(number: 4, recordedAt: sameMoment)}\n';

      final log = buildEventLog([parseEventFile('a', text)], now: testNow);

      expect(eventNumbers(log), [4, 9]);
    });

    test('a sync conflict copy does not duplicate events', () {
      final line1 = eventLine(
        number: 1,
        recordedAt: '2026-11-17T08:00:00.000+00:00',
      );
      final line2 = eventLine(
        number: 2,
        recordedAt: '2026-11-17T09:00:00.000+00:00',
      );
      final original = parseEventFile('$phoneId.jsonl', '$line1\n$line2\n');
      final conflictCopy = parseEventFile(
        '$phoneId.sync-conflict-20261117-090000-ABCDEFG.jsonl',
        '$line1\n',
      );

      final log = buildEventLog([original, conflictCopy], now: testNow);

      expect(eventNumbers(log), [1, 2]);
      expect(log.problems, isEmpty);
    });

    test('two different events with the same id are reported', () {
      final first = eventLine(
        number: 1,
        recordedAt: '2026-11-17T08:00:00.000+00:00',
      );
      final different = eventLine(
        number: 1,
        recordedAt: '2026-11-17T08:00:00.000+00:00',
        data: {'value': 2},
      );

      final log = buildEventLog([
        parseEventFile('a.jsonl', '$first\n'),
        parseEventFile('b.jsonl', '$different\n'),
      ], now: testNow);

      expect(log.events, hasLength(1));
      expect(log.events.single.data, isEmpty);
      expect(log.problems.single.fileName, 'b.jsonl');
      expect(log.problems.single.lineNumber, isNull);
    });

    test('events from a newer format version are set aside and counted', () {
      final text =
          '${eventLine(number: 1, recordedAt: '2026-11-17T08:00:00.000+00:00')}\n'
          '${eventLine(number: 2, recordedAt: '2026-11-17T09:00:00.000+00:00', formatVersion: 2)}\n';

      final log = buildEventLog([parseEventFile('a', text)], now: testNow);

      expect(eventNumbers(log), [1]);
      expect(log.newerVersionEventCount, 1);
    });

    test('events dated more than a few minutes ahead are counted', () {
      final text =
          // Two minutes ahead: normal clock difference, not counted.
          '${eventLine(number: 1, recordedAt: '2026-11-18T12:02:00.000+00:00')}\n'
          // A day ahead: counted.
          '${eventLine(number: 2, recordedAt: '2026-11-19T12:00:00.000+00:00')}\n';

      final log = buildEventLog([parseEventFile('a', text)], now: testNow);

      expect(log.events, hasLength(2));
      expect(log.futureEventCount, 1);
    });

    test('problems from all files are collected', () {
      final log = buildEventLog([
        parseEventFile('a.jsonl', 'broken\n'),
        parseEventFile('b.jsonl', 'also broken\n'),
      ], now: testNow);

      expect(log.problems.map((problem) => problem.fileName), [
        'a.jsonl',
        'b.jsonl',
      ]);
    });

    test('last seen is the latest event of each device', () {
      final phone = parseEventFile(
        '$phoneId.jsonl',
        '${eventLine(number: 2, recordedAt: '2026-11-17T10:00:00.000+09:00', deviceName: 'my-phone')}\n'
            '${eventLine(number: 1, recordedAt: '2026-11-17T08:00:00.000+09:00', deviceName: 'old-name')}\n',
      );
      final desktop = parseEventFile(
        '$desktopId.jsonl',
        '${eventLine(number: 3, recordedAt: '2026-11-16T20:00:00.000+00:00', deviceId: desktopId, deviceName: 'my-desktop')}\n',
      );

      final log = buildEventLog([phone, desktop], now: testNow);

      final phoneSeen = log.lastSeenByDevice[phoneId]!;
      expect(phoneSeen.deviceName, 'my-phone');
      expect(phoneSeen.latestRecordedAt, '2026-11-17T10:00:00.000+09:00');
      expect(log.lastSeenByDevice[desktopId]!.deviceName, 'my-desktop');
    });
  });
}
