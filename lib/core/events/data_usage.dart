// SPDX-License-Identifier: GPL-3.0-or-later

/// How much room Ippo's files take in the data folder.
library;

import '../storage/data_folder.dart';
import 'event_log_reader.dart';
import 'monthly_backup.dart';

/// The room taken by the event files and by the backups, in bytes.
class DataUsage {
  /// Creates the measurement.
  const DataUsage({required this.eventBytes, required this.backupBytes});

  /// Every device's event file together: the data itself.
  final int eventBytes;

  /// Every backup, monthly and manual.
  final int backupBytes;

  /// Both together.
  int get totalBytes => eventBytes + backupBytes;
}

/// Measures the events and backups folders in [dataFolder]. Only sizes
/// are read, never the files' contents.
Future<DataUsage> measureDataUsage(DataFolder dataFolder) async {
  return DataUsage(
    eventBytes: await dataFolder.sizeInBytes(eventsFolderName),
    backupBytes: await dataFolder.sizeInBytes(backupsFolderName),
  );
}

/// Writes a number of bytes for people, as Android's Files app does:
/// `0 B`, `830 B`, `12 kB`, `4.6 MB`, `1.2 GB`. A kilobyte is 1000 bytes.
String formatBytes(int bytes) {
  if (bytes < 1000) {
    return '$bytes B';
  }
  const units = ['kB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  // One decimal for small values ("4.6 MB"); none from 10 on ("12 kB").
  final digits = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
