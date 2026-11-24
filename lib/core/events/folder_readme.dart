// SPDX-License-Identifier: GPL-3.0-or-later

/// A short note in the data folder that says what the files are.
///
/// Someone who copies the data folder to another computer, or finds it
/// years later, should not need the app to understand it. So the app
/// puts this `README.txt` next to the `events/` folder once. It is
/// never read by the app, and never changed after it is written.
library;

import '../storage/data_folder.dart';

/// The note's file name, inside the data folder.
const String folderReadmeName = 'README.txt';

/// The note's text. It describes only what every version of the format
/// keeps, so it never needs to change.
const String folderReadmeText = '''
This folder holds data from Ippo, a health and habit tracker.

events/
  One file per device (each install of the app), named after a random
  device id. Each line is one event in JSON: something that happened,
  such as "a habit was marked done" or "a food was eaten". Lines are
  only ever added; mistakes are fixed by adding a new event.
  Read every file here (except hidden ones starting with "."), and
  remove repeated events by their "id".

backups/
  Monthly copies of each device's event file. They repeat what is in
  events/, so leave them out of an analysis.

To analyze the data, copy this folder to your computer. Ippo's source
code includes a small Python package that turns the events into tidy
tables (habits, food, exercise sets, sleep, and one row per day), and
the full description of the format in docs/data-format.md.
''';

/// Writes [folderReadmeText] to [folderReadmeName], unless that file is
/// already there. Returns true if it was written.
///
/// Throws [DataFolderException] if the note is missing and cannot be
/// written.
Future<bool> writeFolderReadme(DataFolder dataFolder) async {
  try {
    await dataFolder.readTextFile(folderReadmeName);
    return false;
  } on DataFolderException {
    // Not there yet (or not readable): write it. Appending to a missing
    // file creates it.
  }
  await dataFolder.appendToTextFile(folderReadmeName, folderReadmeText);
  return true;
}
