// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [collectThings].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/events/event.dart';
import 'package:ippo/core/events/things.dart';

/// Makes an event; [number] makes the id unique and sets the order.
Event makeEvent(
  int number,
  String type,
  Map<String, Object?> data, {
  String module = 'food',
}) {
  return Event(
    formatVersion: 1,
    id: '019a8f3c-1111-7000-8000-${number.toString().padLeft(12, '0')}',
    recordedAt: '2026-11-17T08:00:00.000+00:00',
    recordedAtUtc: DateTime.utc(2026, 11, 17, 8, 0, number),
    deviceId: '019a8f3c-0000-7000-8000-000000000001',
    deviceName: 'my-phone',
    module: module,
    type: type,
    data: data,
  );
}

const String firstFoodId = '019a8f3c-1111-7000-8000-000000000001';

Map<String, ThingRecord> collectFoods(List<Event> events) => collectThings(
  events,
  module: 'food',
  createdType: 'food_created',
  thingName: 'food',
);

void main() {
  test('a created thing has the fields of its creating event', () {
    final things = collectFoods([
      makeEvent(1, 'food_created', {'name': 'Rolled oats', 'measured_in': 'g'}),
    ]);

    final oats = things[firstFoodId]!;
    expect(oats.fields['name'], 'Rolled oats');
    expect(oats.isDeleted, isFalse);
  });

  test('changes replace only the listed fields', () {
    final things = collectFoods([
      makeEvent(1, 'food_created', {'name': 'Oats', 'measured_in': 'g'}),
      makeEvent(2, 'food_changed', {
        'target_id': firstFoodId,
        'changes': {'name': 'Rolled oats'},
      }),
    ]);

    expect(things[firstFoodId]!.fields, {
      'name': 'Rolled oats',
      'measured_in': 'g',
    });
  });

  test('a changed object field is replaced as a whole', () {
    final things = collectFoods([
      makeEvent(1, 'food_created', {
        'nutrients': {'energy_kcal': 100, 'fat_g': 5},
      }),
      makeEvent(2, 'food_changed', {
        'target_id': firstFoodId,
        'changes': {
          'nutrients': {'energy_kcal': 120},
        },
      }),
    ]);

    expect(things[firstFoodId]!.fields['nutrients'], {'energy_kcal': 120});
  });

  test('deleting and restoring', () {
    final deleted = collectFoods([
      makeEvent(1, 'food_created', {'name': 'Oats'}),
      makeEvent(2, 'food_deleted', {'target_id': firstFoodId}),
    ]);
    final restored = collectFoods([
      makeEvent(1, 'food_created', {'name': 'Oats'}),
      makeEvent(2, 'food_deleted', {'target_id': firstFoodId}),
      makeEvent(3, 'food_restored', {'target_id': firstFoodId}),
    ]);

    expect(deleted[firstFoodId]!.isDeleted, isTrue);
    expect(restored[firstFoodId]!.isDeleted, isFalse);
  });

  test('later changes win', () {
    final things = collectFoods([
      makeEvent(1, 'food_created', {'name': 'A'}),
      makeEvent(2, 'food_changed', {
        'target_id': firstFoodId,
        'changes': {'name': 'B'},
      }),
      makeEvent(3, 'food_changed', {
        'target_id': firstFoodId,
        'changes': {'name': 'C'},
      }),
    ]);

    expect(things[firstFoodId]!.fields['name'], 'C');
  });

  test('changes to a thing that was never created are ignored', () {
    final things = collectFoods([
      makeEvent(1, 'food_changed', {
        'target_id': '019a8f3c-1111-7000-8000-999999999999',
        'changes': {'name': 'Ghost'},
      }),
    ]);

    expect(things, isEmpty);
  });

  test('other modules and malformed changes are ignored', () {
    final things = collectFoods([
      makeEvent(1, 'food_created', {'name': 'Oats'}),
      makeEvent(2, 'food_created', {'name': 'X'}, module: 'habits'),
      makeEvent(3, 'food_changed', {'target_id': 42, 'changes': {}}),
      makeEvent(4, 'food_changed', {
        'target_id': firstFoodId,
        'changes': 'not an object',
      }),
    ]);

    expect(things.keys, [firstFoodId]);
    expect(things[firstFoodId]!.fields['name'], 'Oats');
  });

  test('a change does not alter the original event data', () {
    final created = makeEvent(1, 'food_created', {'name': 'Oats'});
    collectFoods([
      created,
      makeEvent(2, 'food_changed', {
        'target_id': firstFoodId,
        'changes': {'name': 'Changed'},
      }),
    ]);

    expect(created.data['name'], 'Oats');
  });
}
