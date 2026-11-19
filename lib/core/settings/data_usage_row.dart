// SPDX-License-Identifier: GPL-3.0-or-later

/// How much room the data takes, for the Data folder card in Settings.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../events/data_usage.dart';
import '../widgets/section_card.dart';

/// A small table of sizes: the event files, the backups, and both
/// together under a line. Names sit at the left and sizes at the right,
/// so the numbers line up like a sum on paper.
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Space used'),
            _SizeLine(label: 'Events', bytes: usage?.eventBytes),
            _SizeLine(label: 'Backups', bytes: usage?.backupBytes),
            const Divider(height: 9),
            _SizeLine(label: 'Total', bytes: usage?.totalBytes, isTotal: true),
          ],
        );
      },
    );
  }
}

/// One line of the table: a name at the left, its size at the right.
class _SizeLine extends StatelessWidget {
  const _SizeLine({
    required this.label,
    required this.bytes,
    this.isTotal = false,
  });

  final String label;

  /// The size, or null while it is being measured.
  final int? bytes;

  /// Whether this is the sum, shown a little bolder.
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: isTotal ? FontWeight.w600 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(bytes == null ? '…' : formatBytes(bytes), style: style),
        ],
      ),
    );
  }
}
