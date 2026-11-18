// SPDX-License-Identifier: GPL-3.0-or-later

/// Merging the events from all devices into one ordered log.
///
/// This follows "Reading and merging" in `docs/data-format.md`. It does
/// no file access itself; `event_log_reader.dart` reads the files and
/// passes their contents here. That keeps this logic easy to test.
library;

import 'event.dart';
import 'event_file_parser.dart';

/// How far in the future an event may be dated before the app warns.
///
/// Clocks on different devices are rarely exactly the same, so a few
/// minutes of difference is normal and not worth a warning.
const Duration futureEventTolerance = Duration(minutes: 5);

/// When the app last saw an event from one device.
class DeviceLastSeen {
  /// Creates a "last seen" record.
  DeviceLastSeen({
    required this.deviceId,
    required this.deviceName,
    required this.latestRecordedAtUtc,
    required this.latestRecordedAt,
  });

  /// The device's id.
  final String deviceId;

  /// The device's name, from its latest event.
  final String deviceName;

  /// The moment of the device's latest event, in UTC.
  final DateTime latestRecordedAtUtc;

  /// The same moment as stored, with the device's time zone offset.
  final String latestRecordedAt;
}

/// All events from all devices, merged and ordered, plus anything the
/// user should be told about.
class EventLog {
  /// Creates an event log. Normal code uses [buildEventLog].
  EventLog({
    required this.events,
    required this.problems,
    required this.newerVersionEventCount,
    required this.futureEventCount,
    required this.lastSeenByDevice,
  });

  /// Every usable event, once each, oldest first.
  final List<Event> events;

  /// Lines that were skipped because they could not be read, or events
  /// that share an id but differ (which should never happen).
  final List<EventLineProblem> problems;

  /// How many events were skipped because a newer version of the app
  /// wrote them. If this is more than zero, the user should update.
  final int newerVersionEventCount;

  /// How many events are dated in the future, which means some device's
  /// clock is probably wrong.
  final int futureEventCount;

  /// The latest event seen from each device, by device id.
  final Map<String, DeviceLastSeen> lastSeenByDevice;
}

/// Merges the parsed event [files] into one [EventLog].
///
/// Steps, as in `docs/data-format.md`:
/// 1. Remove duplicate events (same id). The same event can appear twice,
///    for example in a sync tool's conflict copy of a file.
/// 2. Set aside events from a newer format version.
/// 3. Sort by time, then by id, so every device gets the same order.
///
/// [now] is the current time; it is a parameter so tests can fix it.
EventLog buildEventLog(List<ParsedEventFile> files, {required DateTime now}) {
  final problems = <EventLineProblem>[];
  final eventsById = <String, Event>{};

  for (final file in files) {
    problems.addAll(file.problems);
    for (final event in file.events) {
      final earlierCopy = eventsById[event.id];
      if (earlierCopy == null) {
        eventsById[event.id] = event;
        continue;
      }
      // A true duplicate is identical and can be ignored. Two different
      // events with one id should never happen, so tell the user.
      if (earlierCopy.toJsonLine() != event.toJsonLine()) {
        problems.add(
          EventLineProblem(
            fileName: file.fileName,
            lineNumber: null,
            reason:
                'two different events share the id ${event.id}; '
                'the first one found is used',
          ),
        );
      }
    }
  }

  final usableEvents = <Event>[];
  var newerVersionEventCount = 0;
  for (final event in eventsById.values) {
    if (event.formatVersion > currentFormatVersion) {
      newerVersionEventCount++;
    } else {
      usableEvents.add(event);
    }
  }
  usableEvents.sort(compareEventsByTime);

  final futureLimit = now.toUtc().add(futureEventTolerance);
  final futureEventCount = eventsById.values
      .where((event) => event.recordedAtUtc.isAfter(futureLimit))
      .length;

  return EventLog(
    events: usableEvents,
    problems: problems,
    newerVersionEventCount: newerVersionEventCount,
    futureEventCount: futureEventCount,
    lastSeenByDevice: _findLastSeen(eventsById.values),
  );
}

/// Orders events by their moment, and by id when the moments are equal.
///
/// Comparing ids as a tie-breaker means every device puts events in
/// exactly the same order, so they all reach the same state.
int compareEventsByTime(Event first, Event second) {
  final byTime = first.recordedAtUtc.compareTo(second.recordedAtUtc);
  if (byTime != 0) {
    return byTime;
  }
  return first.id.compareTo(second.id);
}

/// Finds each device's latest event, including events from newer
/// versions: they still show that the device was active.
Map<String, DeviceLastSeen> _findLastSeen(Iterable<Event> events) {
  final lastSeen = <String, DeviceLastSeen>{};
  for (final event in events) {
    final known = lastSeen[event.deviceId];
    if (known != null &&
        !event.recordedAtUtc.isAfter(known.latestRecordedAtUtc)) {
      continue;
    }
    lastSeen[event.deviceId] = DeviceLastSeen(
      deviceId: event.deviceId,
      deviceName: event.deviceName,
      latestRecordedAtUtc: event.recordedAtUtc,
      latestRecordedAt: event.recordedAt,
    );
  }
  return lastSeen;
}
