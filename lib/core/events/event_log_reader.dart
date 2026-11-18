// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading every device's event file from the data folder.
library;

import '../storage/data_folder.dart';
import 'event_file_parser.dart';
import 'event_log.dart';

/// The folder inside the data folder that holds the event files.
const String eventsFolderName = 'events';

/// Reads all event files in the data folder and merges them.
///
/// Every non-hidden file in `events/` is read, whatever its name. That
/// includes conflict copies made by sync tools, so no event is lost;
/// duplicates are removed by id. Hidden files (starting with `.`) are
/// skipped, because sync tools use them for unfinished downloads.
///
/// [now] is the current time; tests pass a fixed one. Throws
/// [DataFolderException] if the folder or a file cannot be read at all.
/// Damaged lines inside a file do not throw; they are listed in
/// [EventLog.problems].
Future<EventLog> readEventLog(DataFolder dataFolder, {DateTime? now}) async {
  final fileNames = await dataFolder.listFileNames(eventsFolderName);
  final parsedFiles = <ParsedEventFile>[];

  for (final fileName in fileNames) {
    if (fileName.startsWith('.')) {
      continue;
    }
    final text = await dataFolder.readTextFile('$eventsFolderName/$fileName');
    parsedFiles.add(parseEventFile(fileName, text));
  }

  return buildEventLog(parsedFiles, now: now ?? DateTime.now());
}
