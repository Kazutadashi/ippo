// SPDX-License-Identifier: GPL-3.0-or-later

/// Writing new events to this device's own event file.
library;

import '../storage/data_folder.dart';
import 'event.dart';
import 'event_log_reader.dart';
import 'timestamp.dart';
import 'uuid_v7.dart';

/// Adds new events to the end of this device's event file,
/// `events/<device id>.jsonl`.
///
/// A device only ever writes to its own file, so sync tools never see two
/// devices change the same file. This class never changes or removes
/// anything already in the file.
class EventWriter {
  /// Creates a writer for the device with [deviceId] and [deviceName].
  ///
  /// [deviceId] must be a lowercase UUID, because it becomes the file
  /// name. [now] gives the current time; tests pass a fixed clock.
  /// Throws [ArgumentError] if [deviceId] is not a UUID.
  EventWriter({
    required this.dataFolder,
    required this.deviceId,
    required this.deviceName,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (!isValidUuid(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'must be a UUID');
    }
  }

  /// Where the events are written.
  final DataFolder dataFolder;

  /// This device's id. It is also the event file's name.
  final String deviceId;

  /// This device's name, stored in each event for display.
  final String deviceName;

  final DateTime Function() _now;

  // The moment of the last event this writer made. See [_nextMoment].
  DateTime? _lastMoment;

  // Writes are done one at a time, in order. Each new write waits for the
  // one before it. Without this, two quick taps could both check the end
  // of the file before either has written.
  Future<void> _previousWrite = Future<void>.value();

  // Whether we already made sure the file ends with a newline. We only
  // need to check once: after that, every line we write ends with one.
  bool _hasCheckedFileEnding = false;

  /// The path of this device's event file inside the data folder.
  String get filePath => '$eventsFolderName/$deviceId.jsonl';

  /// Creates an event and appends it to this device's file.
  ///
  /// Returns the event that was written. Throws [DataFolderException] if
  /// the file cannot be written; the event is then not saved.
  Future<Event> write({
    required String module,
    required String type,
    required Map<String, Object?> data,
  }) {
    final moment = _nextMoment();
    final recordedAt = formatTimestamp(moment);
    final event = Event(
      formatVersion: currentFormatVersion,
      id: generateUuidV7(now: moment),
      recordedAt: recordedAt,
      // Read the moment back from the text, which keeps only milliseconds,
      // so this event sorts exactly as it will after being read from disk.
      recordedAtUtc: parseTimestamp(recordedAt)!,
      deviceId: deviceId,
      deviceName: deviceName,
      module: module,
      type: type,
      data: data,
    );

    final thisWrite = _previousWrite.then((_) => _appendEvent(event));
    // The next write waits for this one, whether it succeeds or fails. A
    // failure is still reported to this caller through thisWrite.
    _previousWrite = thisWrite.then<void>((_) {}, onError: (Object _) {});
    return thisWrite.then((_) => event);
  }

  /// Returns the current time, but always at least one millisecond after
  /// the previous event from this writer.
  ///
  /// Events are ordered by time. If two events from this device had the
  /// same millisecond, they would be ordered by their random ids, and
  /// "habit changed" could land before "habit created". Moving the second
  /// one a millisecond later keeps the order they were made in.
  DateTime _nextMoment() {
    // Whole milliseconds only, because that is all the timestamp keeps.
    final now = _now();
    var moment = now.subtract(Duration(microseconds: now.microsecond));
    final lastMoment = _lastMoment;
    if (lastMoment != null && !moment.isAfter(lastMoment)) {
      moment = lastMoment.add(const Duration(milliseconds: 1));
    }
    _lastMoment = moment;
    return moment;
  }

  Future<void> _appendEvent(Event event) async {
    var text = '${event.toJsonLine()}\n';
    if (!_hasCheckedFileEnding) {
      if (await _fileEndsWithoutNewline()) {
        // The app was probably stopped in the middle of a write. Start on
        // a fresh line so the damaged line stays separate; readers skip
        // it and tell the user.
        text = '\n$text';
      }
      _hasCheckedFileEnding = true;
    }
    await dataFolder.appendToTextFile(filePath, text);
  }

  Future<bool> _fileEndsWithoutNewline() async {
    final fileNames = await dataFolder.listFileNames(eventsFolderName);
    if (!fileNames.contains('$deviceId.jsonl')) {
      return false;
    }
    final existingText = await dataFolder.readTextFile(filePath);
    return existingText.isNotEmpty && !existingText.endsWith('\n');
  }
}
