// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for reading and writing a single [Event].
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/event.dart';

/// A valid event line, as a map, for tests to change one field at a time.
Map<String, Object?> validEventJson() => {
  'format_version': 1,
  'id': '019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a',
  'recorded_at': '2026-11-17T21:04:11.123+09:00',
  'device_id': '019a8f3c-0000-7000-8000-000000000001',
  'device_name': 'my-phone',
  'module': 'habits',
  'type': 'habit_entry_recorded',
  'data': {'habit_id': 'abc', 'date': '2026-11-17', 'value': 12},
};

void main() {
  test('a valid line is read with all its fields', () {
    final event = Event.fromJsonLine(jsonEncode(validEventJson()));

    expect(event.formatVersion, 1);
    expect(event.id, '019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a');
    expect(event.recordedAt, '2026-11-17T21:04:11.123+09:00');
    expect(event.recordedAtUtc, DateTime.utc(2026, 11, 17, 12, 4, 11, 123));
    expect(event.deviceName, 'my-phone');
    expect(event.module, 'habits');
    expect(event.type, 'habit_entry_recorded');
    expect(event.data['value'], 12);
  });

  test('writing and reading back gives the same line', () {
    final line = jsonEncode(validEventJson());
    expect(Event.fromJsonLine(line).toJsonLine(), line);
  });

  test('fields are written in the documented order', () {
    final event = Event.fromJsonLine(jsonEncode(validEventJson()));
    final keys = (jsonDecode(event.toJsonLine()) as Map<String, Object?>).keys;
    expect(keys.toList(), [
      'format_version',
      'id',
      'recorded_at',
      'device_id',
      'device_name',
      'module',
      'type',
      'data',
    ]);
  });

  test('unknown extra fields are ignored', () {
    final json = validEventJson()..['added_in_a_later_version'] = true;
    final event = Event.fromJsonLine(jsonEncode(json));
    expect(event.id, '019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a');
  });

  test('events from a newer format version can still be read', () {
    final json = validEventJson()..['format_version'] = 2;
    expect(Event.fromJsonLine(jsonEncode(json)).formatVersion, 2);
  });

  group('invalid lines are refused with a reason', () {
    final badLines = <String, String>{
      'not JSON': '{"format_version": 1,',
      'a JSON list': '[1, 2, 3]',
      'missing id': jsonEncode(validEventJson()..remove('id')),
      'id not a UUID': jsonEncode(validEventJson()..['id'] = 'abc'),
      'version as text': jsonEncode(validEventJson()..['format_version'] = '1'),
      'version zero': jsonEncode(validEventJson()..['format_version'] = 0),
      'no time zone': jsonEncode(
        validEventJson()..['recorded_at'] = '2026-11-17T21:04:11.123',
      ),
      'empty module': jsonEncode(validEventJson()..['module'] = ''),
      'missing type': jsonEncode(validEventJson()..remove('type')),
      'data as text': jsonEncode(validEventJson()..['data'] = 'x'),
      'device name as number': jsonEncode(
        validEventJson()..['device_name'] = 5,
      ),
    };

    badLines.forEach((description, line) {
      test(description, () {
        expect(
          () => Event.fromJsonLine(line),
          throwsA(isA<EventFormatException>()),
        );
      });
    });
  });
}
