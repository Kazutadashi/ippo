// SPDX-License-Identifier: GPL-3.0-or-later

/// Working out the current state of "things" (habits, foods, sets, ...)
/// from their events.
///
/// See "Changing and deleting things" in `docs/data-format.md`. A thing
/// is created by one event. Later events change some of its fields,
/// delete it, or restore it. This file applies those events in order and
/// returns each thing's current fields. Modules then turn the fields
/// into their own classes.
library;

import 'event.dart';

/// The current state of one thing, after applying all its events.
class ThingRecord {
  /// Creates a record. Normal code uses [collectThings].
  ThingRecord({
    required this.id,
    required this.fields,
    required this.isDeleted,
    required this.createdAtUtc,
  });

  /// The thing's id: the id of the event that created it.
  final String id;

  /// The thing's fields: those from the creating event, with every later
  /// change applied.
  final Map<String, Object?> fields;

  /// Whether the thing is currently deleted.
  final bool isDeleted;

  /// When the thing was created: the moment its creating event was
  /// written, in UTC.
  final DateTime createdAtUtc;
}

/// Collects the things of one kind in [module] from [events].
///
/// [createdType] is the event type that creates such a thing, for
/// example `food_created`. [thingName] is the prefix of the other event
/// types, for example `food` for `food_changed`, `food_deleted` and
/// `food_restored`.
///
/// [events] must be in log order (oldest first), as in `EventLog.events`.
/// Changes to a thing that has no creating event (for example because
/// that event has not synced yet) are ignored. Returns the things by id,
/// in the order they were created.
Map<String, ThingRecord> collectThings(
  List<Event> events, {
  required String module,
  required String createdType,
  required String thingName,
}) {
  final fieldsById = <String, Map<String, Object?>>{};
  final createdAtById = <String, DateTime>{};
  final deletedIds = <String>{};

  for (final event in events) {
    if (event.module != module) {
      continue;
    }
    if (event.type == createdType) {
      fieldsById[event.id] = Map<String, Object?>.of(event.data);
      createdAtById[event.id] = event.recordedAtUtc;
      continue;
    }

    final targetId = event.data['target_id'];
    if (targetId is! String) {
      continue;
    }
    final fields = fieldsById[targetId];
    if (fields == null) {
      continue;
    }

    if (event.type == '${thingName}_changed') {
      final changes = event.data['changes'];
      if (changes is Map<String, Object?>) {
        // Each listed field replaces the old value as a whole.
        fields.addAll(changes);
      }
    } else if (event.type == '${thingName}_deleted') {
      deletedIds.add(targetId);
    } else if (event.type == '${thingName}_restored') {
      deletedIds.remove(targetId);
    }
  }

  return {
    for (final entry in fieldsById.entries)
      entry.key: ThingRecord(
        id: entry.key,
        fields: entry.value,
        isDeleted: deletedIds.contains(entry.key),
        createdAtUtc: createdAtById[entry.key]!,
      ),
  };
}
