// SPDX-License-Identifier: GPL-3.0-or-later

/// "Back up now" and "Clear all data", from Settings.
///
/// A backup copies every event file into a new folder under `backups/`,
/// which the app never reads. Clearing deletes every event file, so the
/// app starts empty; it always makes a backup first. See "backups" in
/// `docs/data-format.md`.
library;

import '../dates.dart';
import '../storage/data_folder.dart';
import 'event_log_reader.dart';
import 'monthly_backup.dart';

/// Copies every event file (from every device) into a new folder,
/// `backups/manual-<date>-<time>/`, named by [now]. Returns that folder's
/// path. Hidden files (a sync tool's half-written files) are left out.
///
/// To restore, copy the files back into `events/`. Throws
/// [DataFolderException] if something cannot be read or written; files
/// copied before the problem stay where they are.
Future<String> backUpAllEvents(
  DataFolder dataFolder, {
  required DateTime now,
}) async {
  final stamp =
      '${formatDate(now)}-'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final backupFolder = '$backupsFolderName/manual-$stamp';
  for (final name in await _eventFileNames(dataFolder)) {
    final text = await dataFolder.readTextFile('$eventsFolderName/$name');
    // Appending to a file that does not exist yet creates it.
    await dataFolder.appendToTextFile('$backupFolder/$name', text);
  }
  return backupFolder;
}

/// Deletes every event file, from every device, after copying them all
/// with [backUpAllEvents]. Returns the backup folder's path.
///
/// Sync tools pass the deletion on to other devices, so the data is gone
/// there too, apart from the backup. Throws [DataFolderException] if the
/// backup or a deletion fails; nothing is deleted unless the backup
/// worked.
Future<String> clearAllEvents(
  DataFolder dataFolder, {
  required DateTime now,
}) async {
  final backupFolder = await backUpAllEvents(dataFolder, now: now);
  for (final name in await _eventFileNames(dataFolder)) {
    await dataFolder.deleteFile('$eventsFolderName/$name');
  }
  return backupFolder;
}

/// The event files, without hidden ones.
Future<List<String>> _eventFileNames(DataFolder dataFolder) async {
  final names = await dataFolder.listFileNames(eventsFolderName);
  return [
    for (final name in names)
      if (!name.startsWith('.')) name,
  ];
}
