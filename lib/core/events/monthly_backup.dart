// SPDX-License-Identifier: GPL-3.0-or-later

/// The monthly backup of this device's event file.
///
/// See "backups" in `docs/data-format.md`. Once a month, a copy of the
/// device's own event file goes to `backups/<device id>/<date>.jsonl`.
/// The app never reads backups; they are a safety net in case an event
/// file is ever damaged.
library;

import '../dates.dart';
import '../storage/data_folder.dart';
import 'event_log_reader.dart';

/// The folder inside the data folder that holds the backups.
const String backupsFolderName = 'backups';

/// Makes this month's backup of the device [deviceId]'s event file,
/// unless one was already made this month.
///
/// [now] is the current time; tests pass a fixed one. Returns true if a
/// backup was made. Does nothing if the device has no events yet. Throws
/// [DataFolderException] if the folder cannot be read or written.
Future<bool> makeMonthlyBackup(
  DataFolder dataFolder, {
  required String deviceId,
  required DateTime now,
}) async {
  final backupFolder = '$backupsFolderName/$deviceId';
  // Backups are named by the day they were made, such as 2026-11-18;
  // any name starting with this month means this month is done.
  final thisMonth = formatDate(now).substring(0, 7);
  final made = await dataFolder.listFileNames(backupFolder);
  if (made.any((name) => name.startsWith(thisMonth))) {
    return false;
  }

  final eventFileName = '$deviceId.jsonl';
  final eventFiles = await dataFolder.listFileNames(eventsFolderName);
  if (!eventFiles.contains(eventFileName)) {
    return false;
  }
  final text = await dataFolder.readTextFile(
    '$eventsFolderName/$eventFileName',
  );
  if (text.isEmpty) {
    return false;
  }
  // Appending to a file that does not exist yet creates it: the backup
  // is a new file holding a copy of the whole event file.
  await dataFolder.appendToTextFile(
    '$backupFolder/${formatDate(now)}.jsonl',
    text,
  );
  return true;
}
