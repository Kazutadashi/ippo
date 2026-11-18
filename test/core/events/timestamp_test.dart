// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for writing and reading timestamps.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/timestamp.dart';

void main() {
  final moment = DateTime.utc(2026, 11, 17, 12, 4, 11, 123);

  group('formatTimestampWithOffset', () {
    test('a positive offset', () {
      expect(
        formatTimestampWithOffset(moment, const Duration(hours: 9)),
        '2026-11-17T21:04:11.123+09:00',
      );
    });

    test('a negative offset with minutes', () {
      expect(
        formatTimestampWithOffset(
          moment,
          const Duration(hours: -3, minutes: -30),
        ),
        '2026-11-17T08:34:11.123-03:30',
      );
    });

    test('UTC is written as +00:00, never Z', () {
      expect(
        formatTimestampWithOffset(moment, Duration.zero),
        '2026-11-17T12:04:11.123+00:00',
      );
    });

    test('the offset can move the date to the next day', () {
      expect(
        formatTimestampWithOffset(
          DateTime.utc(2026, 12, 31, 20),
          const Duration(hours: 5),
        ),
        '2027-01-01T01:00:00.000+05:00',
      );
    });
  });

  test('formatTimestamp uses the local offset and keeps the moment', () {
    final text = formatTimestamp(moment);
    expect(parseTimestamp(text), moment);
  });

  group('parseTimestamp', () {
    test('reads offsets into the same UTC moment', () {
      expect(parseTimestamp('2026-11-17T21:04:11.123+09:00'), moment);
      expect(parseTimestamp('2026-11-17T08:34:11.123-03:30'), moment);
    });

    test('accepts Z and other fraction lengths from other tools', () {
      expect(parseTimestamp('2026-11-17T12:04:11.123Z'), moment);
      expect(
        parseTimestamp('2026-11-17T12:04:11+00:00'),
        DateTime.utc(2026, 11, 17, 12, 4, 11),
      );
    });

    test('refuses timestamps without a time zone', () {
      expect(parseTimestamp('2026-11-17T12:04:11.123'), isNull);
    });

    test('refuses text that is not a timestamp', () {
      expect(parseTimestamp(''), isNull);
      expect(parseTimestamp('2026-11-17'), isNull);
      expect(parseTimestamp('yesterday'), isNull);
      expect(parseTimestamp('2026-13-45T99:99:99+00:00'), isNull);
      expect(parseTimestamp('2026-04-31T12:00:00.000+00:00'), isNull);
      expect(parseTimestamp('2026-02-29T12:00:00.000+00:00'), isNull);
      expect(parseTimestamp('2026-11-17T24:00:00.000+00:00'), isNull);
      expect(parseTimestamp('2026-11-17T12:00:00.000+25:00'), isNull);
      expect(parseTimestamp('2026-00-10T12:00:00.000+00:00'), isNull);
    });

    test('accepts a real leap day', () {
      expect(
        parseTimestamp('2028-02-29T12:00:00.000+00:00'),
        DateTime.utc(2028, 2, 29, 12),
      );
    });
  });
}
