// SPDX-License-Identifier: GPL-3.0-or-later

/// How much room the data takes, for the Data folder card in Settings.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../events/data_usage.dart';
import '../widgets/section_card.dart';

/// Three values side by side: the event files, the backups, and both.
///
/// It measures the folder when it first appears, and again whenever the
/// data was read again or something new was saved.
class DataUsageRow extends StatefulWidget {
  /// Creates the row for [appState]'s data folder.
  const DataUsageRow({super.key, required this.appState});

  /// The app-wide state, holding the data folder.
  final AppState appState;

  @override
  State<DataUsageRow> createState() => _DataUsageRowState();
}

class _DataUsageRowState extends State<DataUsageRow> {
  Future<DataUsage>? _usage;

  /// What the last measurement was taken for: the event log and how many
  /// events it had. When either changes, the folder has changed too.
  Object? _measuredFor;

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final dataFolder = appState.dataFolder;
    if (dataFolder == null) {
      return const SizedBox.shrink();
    }
    final eventLog = appState.eventLog;
    final state = (eventLog, eventLog?.events.length);
    if (_usage == null || state != _measuredFor) {
      _measuredFor = state;
      _usage = measureDataUsage(dataFolder);
    }
    return FutureBuilder(
      future: _usage,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const NoteText('Could not measure the data folder.');
        }
        final usage = snapshot.data;
        String show(int? bytes) => bytes == null ? '…' : formatBytes(bytes);
        return InfoRow(
          values: [
            InfoValue(label: 'Events', value: show(usage?.eventBytes)),
            InfoValue(label: 'Backups', value: show(usage?.backupBytes)),
            InfoValue(label: 'Total', value: show(usage?.totalBytes)),
          ],
        );
      },
    );
  }
}
