// SPDX-License-Identifier: GPL-3.0-or-later

/// Making up data for the demo: a few weeks of everyday use, ending now.
///
/// Each module makes up its own events (see `IppoModule.demoEvents`)
/// with the help of a [DemoPlan], so a new module can add demo data
/// without changing anything here. The events are made fresh each time,
/// around today, so the demo always looks current; nothing is stored in
/// the app and nothing is downloaded.
library;

import 'dart:math';

import '../dates.dart';
import '../events/event.dart';
import '../events/timestamp.dart';
import '../events/uuid_v7.dart';

/// The demo's device: the made-up events look as if another phone wrote
/// them. A fixed id, so it never clashes with a real device.
const String demoDeviceId = '01900000-0000-7000-8000-00000000de30';

/// The demo device's name, shown in Settings under Devices.
const String demoDeviceName = 'Demo data';

/// One made-up event, before it is written out.
class DemoEvent {
  /// Creates an event that happened at [moment].
  const DemoEvent({
    required this.id,
    required this.moment,
    required this.module,
    required this.type,
    required this.data,
  });

  /// The event's id. Other events refer to it: a meal to its food, a
  /// check-off to its habit.
  final String id;

  /// When it was recorded.
  final DateTime moment;

  /// The module, such as `food`.
  final String module;

  /// The event type, such as `food_created`.
  final String type;

  /// The event's data, as described in `docs/data-format.md`.
  final Map<String, Object?> data;
}

/// The days the demo covers, ending today, and helpers for making up
/// events on them.
///
/// Its random numbers come from a fixed seed, so the demo is the same
/// every time apart from the dates.
class DemoPlan {
  /// Creates a plan for [dayCount] days ending on the day of [now].
  DemoPlan({required this.now, this.dayCount = 28})
    : today = currentDay(now),
      random = Random(20261120);

  /// The moment the demo starts. Nothing is made up after it.
  final DateTime now;

  /// The day of [now] (see `currentDay`), at midnight.
  final DateTime today;

  /// How many days the demo covers.
  final int dayCount;

  /// Random numbers for making things vary from day to day.
  final Random random;

  /// The first day, at midnight.
  DateTime get firstDay => addDays(today, -(dayCount - 1));

  /// Every day the demo covers, oldest first.
  List<DateTime> get days => [
    for (var index = 0; index < dayCount; index++) addDays(firstDay, index),
  ];

  /// How many days before today [day] is: 0 for today.
  int daysAgo(DateTime day) => today.difference(day).inDays;

  /// [hours] after midnight on [day], such as 7.5 for 07:30. Hours past
  /// 24 run into the next morning.
  DateTime at(DateTime day, double hours) =>
      day.add(Duration(minutes: (hours * 60).round()));

  /// A random amount between -[spread] and +[spread].
  double wobble(double spread) => (random.nextDouble() * 2 - 1) * spread;

  /// Whether something happens, with the given [chance] from 0 to 1.
  bool chance(double chance) => random.nextDouble() < chance;

  /// Makes up an event recorded at [moment].
  ///
  /// Its id draws from [random], so every event shifts the numbers that
  /// follow. Events added to the demo later can pass their own
  /// [idRandom] instead, so the rest of the demo stays as it was.
  DemoEvent event(
    DateTime moment,
    String module,
    String type,
    Map<String, Object?> data, {
    Random? idRandom,
  }) {
    return DemoEvent(
      id: generateUuidV7(now: moment, random: idRandom ?? random),
      moment: moment,
      module: module,
      type: type,
      data: data,
    );
  }
}

/// Writes [events] as the text of one event file (one JSON line each),
/// oldest first, from the demo device. Events after [now] are left out:
/// the demo never shows something that has not happened yet.
String demoEventFile(List<DemoEvent> events, {required DateTime now}) {
  final sorted = [
    for (final event in events)
      if (!event.moment.isAfter(now)) event,
  ]..sort((a, b) => a.moment.compareTo(b.moment));
  final lines = StringBuffer();
  for (final demo in sorted) {
    final recordedAt = formatTimestamp(demo.moment);
    final event = Event(
      formatVersion: currentFormatVersion,
      id: demo.id,
      recordedAt: recordedAt,
      recordedAtUtc: parseTimestamp(recordedAt)!,
      deviceId: demoDeviceId,
      deviceName: demoDeviceName,
      module: demo.module,
      type: demo.type,
      data: demo.data,
    );
    lines.writeln(event.toJsonLine());
  }
  return lines.toString();
}
