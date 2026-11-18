// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [generateUuidV7] and [isValidUuid].
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/uuid_v7.dart';

void main() {
  test('ids have the UUID shape, version 7 and the standard variant', () {
    for (var attempt = 0; attempt < 100; attempt++) {
      final id = generateUuidV7();
      expect(isValidUuid(id), isTrue, reason: id);
      expect(id[14], '7', reason: 'version digit in $id');
      expect('89ab', contains(id[19]), reason: 'variant digit in $id');
    }
  });

  test('the first 48 bits hold the time in milliseconds', () {
    final moment = DateTime.utc(2026, 11, 17, 12, 0, 0, 123);
    final id = generateUuidV7(now: moment, random: Random(1));

    final timeHex = id.substring(0, 8) + id.substring(9, 13);
    expect(int.parse(timeHex, radix: 16), moment.millisecondsSinceEpoch);
  });

  test('ids made later sort after ids made earlier', () {
    final earlier = generateUuidV7(now: DateTime.utc(2026, 1, 1));
    final later = generateUuidV7(now: DateTime.utc(2026, 1, 1, 0, 0, 0, 1));
    expect(earlier.compareTo(later), lessThan(0));
  });

  test('many ids made at the same moment are all different', () {
    final moment = DateTime.utc(2026, 1, 1);
    final ids = {for (var i = 0; i < 1000; i++) generateUuidV7(now: moment)};
    expect(ids, hasLength(1000));
  });

  test('isValidUuid refuses other shapes', () {
    expect(isValidUuid('019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a'), isTrue);
    expect(isValidUuid('019A8F3C-5B2E-7C41-9D3A-2F6E8B1C4D5A'), isFalse);
    expect(isValidUuid('019a8f3c5b2e7c419d3a2f6e8b1c4d5a'), isFalse);
    expect(isValidUuid('../../etc/passwd'), isFalse);
    expect(isValidUuid(''), isFalse);
  });
}
