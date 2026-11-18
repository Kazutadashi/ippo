// SPDX-License-Identifier: GPL-3.0-or-later

/// The event: one line in an event file.
///
/// See "Events" in `docs/data-format.md` for what each field means.
library;

import 'dart:convert';

import 'timestamp.dart';
import 'uuid_v7.dart';

/// The format version this app writes. See "Versions and compatibility"
/// in `docs/data-format.md`.
const int currentFormatVersion = 1;

/// One event: a small record of something that happened.
///
/// Events are never changed after they are written. To read one from a
/// file, use [Event.fromJsonLine]; to write one, use [toJsonLine].
class Event {
  /// Creates an event. Normal code gets events from `EventWriter` or
  /// [Event.fromJsonLine] instead of calling this directly.
  Event({
    required this.formatVersion,
    required this.id,
    required this.recordedAt,
    required this.recordedAtUtc,
    required this.deviceId,
    required this.deviceName,
    required this.module,
    required this.type,
    required this.data,
  });

  /// Reads an event from one line of an event file.
  ///
  /// Throws [EventFormatException] if the line is not a valid event.
  /// Unknown extra fields are ignored, so events from newer app versions
  /// still load.
  factory Event.fromJsonLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      throw EventFormatException('not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw EventFormatException('not a JSON object');
    }

    final formatVersion = decoded['format_version'];
    if (formatVersion is! int || formatVersion < 1) {
      throw EventFormatException('"format_version" is not a positive integer');
    }

    final id = _requireText(decoded, 'id');
    if (!isValidUuid(id)) {
      throw EventFormatException('"id" is not a lowercase UUID');
    }

    final recordedAt = _requireText(decoded, 'recorded_at');
    final recordedAtUtc = parseTimestamp(recordedAt);
    if (recordedAtUtc == null) {
      throw EventFormatException(
        '"recorded_at" is not a timestamp with a time zone',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw EventFormatException('"data" is not a JSON object');
    }

    return Event(
      formatVersion: formatVersion,
      id: id,
      recordedAt: recordedAt,
      recordedAtUtc: recordedAtUtc,
      deviceId: _requireText(decoded, 'device_id'),
      deviceName: _requireText(decoded, 'device_name'),
      module: _requireText(decoded, 'module'),
      type: _requireText(decoded, 'type'),
      data: data,
    );
  }

  /// The version of the data format this event follows.
  final int formatVersion;

  /// The event's unique id, a lowercase UUID.
  final String id;

  /// When the event was written, exactly as stored, with the local time
  /// zone offset. Keeping the text keeps the local time of day.
  final String recordedAt;

  /// The same moment as [recordedAt], in UTC. Used for sorting.
  final DateTime recordedAtUtc;

  /// The id of the device that wrote the event.
  final String deviceId;

  /// The device's name when the event was written. Only for display.
  final String deviceName;

  /// The module the event belongs to, for example `habits`.
  final String module;

  /// What happened, for example `habit_created`.
  final String type;

  /// The details. Their fields depend on [module] and [type].
  final Map<String, Object?> data;

  /// Writes the event as one line of JSON, without the final newline.
  ///
  /// Fields are written in the order listed in `docs/data-format.md`.
  String toJsonLine() {
    return jsonEncode({
      'format_version': formatVersion,
      'id': id,
      'recorded_at': recordedAt,
      'device_id': deviceId,
      'device_name': deviceName,
      'module': module,
      'type': type,
      'data': data,
    });
  }
}

/// A line in an event file that is not a valid event.
class EventFormatException implements Exception {
  /// Creates an exception explaining what is wrong with the line.
  EventFormatException(this.reason);

  /// What is wrong, in plain words, for example `"id" is missing`.
  final String reason;

  @override
  String toString() => 'EventFormatException: $reason';
}

/// Returns the non-empty text field [name], or throws
/// [EventFormatException].
String _requireText(Map<String, Object?> json, String name) {
  final value = json[name];
  if (value is! String || value.isEmpty) {
    throw EventFormatException('"$name" is missing or not text');
  }
  return value;
}
