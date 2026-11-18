// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the date and number helpers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/number_input.dart';

void main() {
  group('dates', () {
    test('formatDate writes YYYY-MM-DD and ignores the time', () {
      expect(formatDate(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });

    test('parseDate reads real dates only', () {
      expect(parseDate('2026-11-17'), DateTime(2026, 11, 17));
      expect(parseDate('2028-02-29'), DateTime(2028, 2, 29));
      expect(parseDate('2026-02-29'), isNull);
      expect(parseDate('2026-04-31'), isNull);
      expect(parseDate('2026-13-01'), isNull);
      expect(parseDate('17.11.2026'), isNull);
      expect(parseDate(''), isNull);
    });

    test('times of day', () {
      expect(formatTimeOfDay(DateTime(2026, 1, 1, 7, 5)), '07:05');
      expect(isValidTimeOfDay('23:59'), isTrue);
      expect(isValidTimeOfDay('24:00'), isFalse);
      expect(isValidTimeOfDay('7:05'), isFalse);
    });

    test('addDays crosses months and years', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });

  group('numbers', () {
    test('parseAmount accepts a dot or a comma', () {
      expect(parseAmount('150'), 150);
      expect(parseAmount(' 12.5 '), 12.5);
      expect(parseAmount('12,5'), 12.5);
    });

    test('parseAmount refuses text and negative numbers', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('-3'), isNull);
      expect(parseAmount('NaN'), isNull);
      expect(parseAmount('Infinity'), isNull);
    });

    test('formatAmount drops needless decimals', () {
      expect(formatAmount(150), '150');
      expect(formatAmount(12.5), '12.5');
      expect(formatAmount(12.34), '12.3');
      expect(formatAmount(0.04), '0');
    });

    test('jsonNumber writes whole numbers as integers', () {
      expect(jsonNumber(280.0), isA<int>());
      expect(jsonNumber(12.5), 12.5);
    });
  });
}
