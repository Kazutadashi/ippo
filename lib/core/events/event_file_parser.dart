// SPDX-License-Identifier: GPL-3.0-or-later

/// Turning the text of one event file into events.
library;

import 'event.dart';

/// A problem found while reading event files, usually a line that
/// could not be read as an event.
///
/// The line is skipped, and the file is never changed. The app shows
/// these problems to the user so nothing goes wrong silently.
class EventLineProblem {
  /// Creates a problem report for one line.
  EventLineProblem({
    required this.fileName,
    required this.lineNumber,
    required this.reason,
  });

  /// The file the line is in, for example `my-device-id.jsonl`.
  final String fileName;

  /// The line's number in the file, counting from 1, or null if the
  /// problem is not about a single line.
  final int? lineNumber;

  /// What is wrong with the line, in plain words.
  final String reason;

  @override
  String toString() {
    final place = lineNumber == null ? fileName : '$fileName line $lineNumber';
    return '$place: $reason';
  }
}

/// The events and problems found in one event file.
class ParsedEventFile {
  /// Creates the result of reading one file.
  ParsedEventFile({
    required this.fileName,
    required this.events,
    required this.problems,
  });

  /// The file's name, for example `my-device-id.jsonl`.
  final String fileName;

  /// The valid events, in the order they appear in the file.
  final List<Event> events;

  /// The lines that were skipped, and why.
  final List<EventLineProblem> problems;
}

/// Reads every line of an event file named [fileName] with contents
/// [text].
///
/// Blank lines are skipped without a problem report: they are harmless,
/// for example after editing a file by hand. Any other line that is not a
/// valid event becomes an [EventLineProblem]. This never throws.
ParsedEventFile parseEventFile(String fileName, String text) {
  final events = <Event>[];
  final problems = <EventLineProblem>[];

  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    // Also accept Windows line endings (\r\n), in case a file was edited
    // on Windows.
    final line = lines[index].trimRight();
    if (line.isEmpty) {
      continue;
    }
    try {
      events.add(Event.fromJsonLine(line));
    } on EventFormatException catch (error) {
      problems.add(
        EventLineProblem(
          fileName: fileName,
          lineNumber: index + 1,
          reason: error.reason,
        ),
      );
    }
  }

  return ParsedEventFile(
    fileName: fileName,
    events: events,
    problems: problems,
  );
}
