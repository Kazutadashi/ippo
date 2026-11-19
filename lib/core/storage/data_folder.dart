// SPDX-License-Identifier: GPL-3.0-or-later

/// The one door to the disk.
///
/// All of Ippo's file access goes through a [DataFolder]. To see exactly
/// what the app can read and write, an auditor only needs to read this
/// folder (`lib/core/storage/`) and its Android half,
/// `android/app/src/main/kotlin/org/ippo/ippo/StorageBridge.kt`.
///
/// A data folder only offers five operations: list files, read a file,
/// append to a file, delete a file, and measure how much room files take. There is deliberately no way to
/// rename or overwrite a file, because Ippo's data is append-only.
/// Deleting is used for one thing only: "Clear all data" in Settings,
/// which the user confirms, and which makes a full backup first.
library;

/// The folder the user picked for their Ippo data.
///
/// Every path given to these methods is relative to that folder and uses
/// `/` between folder names, for example `events/my-device.jsonl`. Paths
/// that could reach outside the folder are refused; see [checkRelativePath].
abstract class DataFolder {
  /// Returns the names of the files directly inside [folderPath], sorted.
  ///
  /// Sub-folders are not included. Returns an empty list if [folderPath]
  /// does not exist yet. Throws [DataFolderException] if it cannot be read.
  Future<List<String>> listFileNames(String folderPath);

  /// Returns the full contents of the file at [filePath] as UTF-8 text.
  ///
  /// Throws [DataFolderException] if the file is missing or unreadable.
  Future<String> readTextFile(String filePath);

  /// Adds [text] to the end of the file at [filePath].
  ///
  /// Creates the file, and any missing folders above it, if needed.
  /// Existing content is never changed. Throws [DataFolderException] if
  /// the file cannot be written.
  Future<void> appendToTextFile(String filePath, String text);

  /// Deletes the file at [filePath]. Never deletes a folder.
  ///
  /// Only "Clear all data" uses this (see `clearAllEvents`). Does nothing
  /// if the file does not exist. Throws [DataFolderException] if it
  /// cannot be deleted.
  Future<void> deleteFile(String filePath);

  /// Returns how many bytes the file at [path] takes, or, for a folder,
  /// all the files inside it and its sub-folders together. Hidden files
  /// and folders (whose names start with `.`), such as a sync tool's own,
  /// are left out, as when reading events.
  ///
  /// Returns 0 if nothing is at [path]. Only sizes are read, never what
  /// is in the files. Settings uses this to show how much room the data
  /// takes. Throws [DataFolderException] if the sizes cannot be read.
  Future<int> sizeInBytes(String path);
}

/// An error while reading or writing the data folder.
///
/// The [message] is meant to be shown to the user.
class DataFolderException implements Exception {
  /// Creates an exception with a message for the user.
  DataFolderException(this.message);

  /// What went wrong, in plain words.
  final String message;

  @override
  String toString() => 'DataFolderException: $message';
}

/// Checks that [path] is a safe path inside the data folder.
///
/// A safe path is not empty, does not start or end with `/`, and none of
/// its parts are empty, `.` or `..`, or contain `\` (a Windows-style
/// separator that could hide a `..`). This keeps every read and write
/// inside the folder the user chose.
///
/// Throws [DataFolderException] if the path is not safe.
void checkRelativePath(String path) {
  final parts = path.split('/');
  final hasBadPart = parts.any(
    (part) =>
        part.isEmpty || part == '.' || part == '..' || part.contains('\\'),
  );
  if (path.isEmpty || hasBadPart) {
    throw DataFolderException(
      'Not a safe path inside the data folder: "$path"',
    );
  }
}
