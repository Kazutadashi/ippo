// SPDX-License-Identifier: GPL-3.0-or-later

/// "Back up now", "Restore a backup" and "Clear all data", from Settings.
///
/// A backup copies every event file into a new folder under `backups/`,
/// which the app never reads. Restoring adds a backup's events back into
/// `events/`. Clearing deletes every event file, so the app starts empty;
/// it always makes a backup first. See "backups" in
/// `docs/data-format.md`.
library;

import 'dart:convert';

import '../dates.dart';
import '../storage/data_folder.dart';
import 'event_log_reader.dart';
import 'monthly_backup.dart';

/// Copies every event file (from every device) into a new folder,
/// `backups/manual-<date>-<time>/`, named by [now]. Returns that folder's
/// path. Hidden files (a sync tool's half-written files) are left out.
///
/// To restore, use [restoreBackup]. Throws
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

/// The prefix of the folders [backUpAllEvents] makes inside `backups/`.
const manualBackupPrefix = 'manual-';

/// The backups made with "Back up now" or "Clear all data", as paths
/// such as `backups/manual-2026-01-02-030405`, newest first. (Their names
/// sort by date and time.) The monthly snapshots are not listed: each
/// holds only one device's file, and the events are in `events/` anyway.
Future<List<String>> listManualBackups(DataFolder dataFolder) async {
  final names = await dataFolder.listFolderNames(backupsFolderName);
  final backups = [
    for (final name in names)
      if (name.startsWith(manualBackupPrefix)) '$backupsFolderName/$name',
  ];
  return backups.reversed.toList();
}

/// Adds the events in [backupFolder] (a path from [listManualBackups])
/// back into `events/`. Returns how many events were added.
///
/// Each backed-up file goes back to the file of the same name, so every
/// event stays in its own device's file. Nothing is replaced or deleted:
/// only lines whose event id is not already in that file are appended,
/// so restoring twice adds nothing the second time, and events written
/// since the backup stay. Lines that cannot be read are left out (they
/// stay in the backup). Throws [DataFolderException] if something cannot
/// be read or written; lines added before the problem stay.
Future<int> restoreBackup(DataFolder dataFolder, String backupFolder) async {
  final present = await _eventFileNames(dataFolder);
  var added = 0;
  for (final name in await dataFolder.listFileNames(backupFolder)) {
    if (name.startsWith('.')) {
      continue;
    }
    final known = <String>{};
    final missing = StringBuffer();
    if (present.contains(name)) {
      final current = await dataFolder.readTextFile('$eventsFolderName/$name');
      known.addAll(_idsIn(current));
      // If the file's last line is unfinished, end it first, so the
      // added lines do not join on to it.
      if (current.isNotEmpty && !current.endsWith('\n')) {
        missing.writeln();
      }
    }
    final backup = await dataFolder.readTextFile('$backupFolder/$name');
    for (final line in const LineSplitter().convert(backup)) {
      final id = _idOf(line);
      if (id != null && known.add(id)) {
        missing.writeln(line);
        added++;
      }
    }
    if (missing.toString().trim().isNotEmpty) {
      await dataFolder.appendToTextFile(
        '$eventsFolderName/$name',
        missing.toString(),
      );
    }
  }
  return added;
}

/// The event ids of the lines in [text], skipping lines without one.
Iterable<String> _idsIn(String text) sync* {
  for (final line in const LineSplitter().convert(text)) {
    final id = _idOf(line);
    if (id != null) {
      yield id;
    }
  }
}

/// The `id` of the event on [line], or null if the line is not a JSON
/// object with a text id (a blank or broken line).
String? _idOf(String line) {
  if (line.trim().isEmpty) {
    return null;
  }
  try {
    final json = jsonDecode(line);
    if (json is Map && json['id'] is String) {
      return json['id'] as String;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// The event files, without hidden ones.
Future<List<String>> _eventFileNames(DataFolder dataFolder) async {
  final names = await dataFolder.listFileNames(eventsFolderName);
  return [
    for (final name in names)
      if (!name.startsWith('.')) name,
  ];
}
