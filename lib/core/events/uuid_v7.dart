// SPDX-License-Identifier: GPL-3.0-or-later

/// Creating and checking ids.
///
/// Ippo uses UUIDv7 ids, defined in RFC 9562
/// (https://datatracker.ietf.org/doc/html/rfc9562). A UUIDv7 starts with
/// the time it was made, so sorting ids roughly sorts them by time. The
/// rest is random, so two devices never make the same id.
library;

import 'dart:math';

/// A random number source that is safe for ids: hard to predict.
final Random _secureRandom = Random.secure();

/// Matches a lowercase UUID such as `019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a`.
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Creates a new UUIDv7 id as a lowercase string.
///
/// [now] and [random] exist so tests can get predictable ids. Normal
/// code leaves them out.
String generateUuidV7({DateTime? now, Random? random}) {
  final randomSource = random ?? _secureRandom;
  final milliseconds = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final bytes = List<int>.filled(16, 0);

  // Bytes 0 to 5: the time, in milliseconds since 1970, biggest part first.
  for (var index = 0; index < 6; index++) {
    final shift = 8 * (5 - index);
    bytes[index] = (milliseconds >> shift) & 0xFF;
  }

  // Bytes 6 to 15: random.
  for (var index = 6; index < 16; index++) {
    bytes[index] = randomSource.nextInt(256);
  }

  // The standard reserves a few bits to say which kind of UUID this is:
  // the top 4 bits of byte 6 are the version (7), and the top 2 bits of
  // byte 8 are the "variant" (binary 10).
  bytes[6] = 0x70 | (bytes[6] & 0x0F);
  bytes[8] = 0x80 | (bytes[8] & 0x3F);

  return _formatAsUuid(bytes);
}

/// Returns true if [text] looks like a lowercase UUID.
///
/// It checks the shape only (8-4-4-4-12 hex digits), not the version, so
/// ids written by other tools are still accepted.
bool isValidUuid(String text) => _uuidPattern.hasMatch(text);

/// Writes 16 bytes as hex digits with dashes: 8-4-4-4-12.
String _formatAsUuid(List<int> bytes) {
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
