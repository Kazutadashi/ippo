// SPDX-License-Identifier: GPL-3.0-or-later

/// The part of the settings screen that lists devices and when each was
/// last seen, plus any problems found while reading the data.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../events/event_log.dart';

/// Shows every device that has written events, with the time of its
/// latest event, so the user can tell whether sync has caught up.
class DevicesSection extends StatelessWidget {
  /// Creates the section.
  const DevicesSection({super.key, required this.appState});

  /// The app-wide state to show.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final eventLog = appState.eventLog;
    if (appState.dataFolder == null) {
      return const Text('Choose a data folder first.');
    }
    if (eventLog == null) {
      return const Text('Reading the data folder…');
    }

    final thisDeviceId = appState.settings?.deviceId;
    final devices = eventLog.lastSeenByDevice.values.toList()
      // Most recently seen first.
      ..sort(
        (first, second) =>
            second.latestRecordedAtUtc.compareTo(first.latestRecordedAtUtc),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (devices.isEmpty) const Text('No events yet, from any device.'),
        for (final device in devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              device.deviceId == thisDeviceId
                  ? Icons.smartphone
                  : Icons.devices_other,
            ),
            title: Text(
              device.deviceId == thisDeviceId
                  ? '${device.deviceName} (this device)'
                  : device.deviceName,
            ),
            subtitle: Text(
              'Last event: ${formatLocalDateTime(device.latestRecordedAtUtc)}',
            ),
          ),
        Text('${eventLog.events.length} events in total.'),
        ..._warnings(eventLog),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: appState.reloadEvents,
          icon: const Icon(Icons.refresh),
          label: const Text('Read the data folder again'),
        ),
      ],
    );
  }

  /// Warnings the user should know about. Nothing is ever hidden: every
  /// skipped line is listed.
  List<Widget> _warnings(EventLog eventLog) {
    return [
      if (eventLog.newerVersionEventCount > 0)
        _WarningText(
          '${eventLog.newerVersionEventCount} events were written by a '
          'newer version of Ippo. Update this app to see them.',
        ),
      if (eventLog.futureEventCount > 0)
        _WarningText(
          '${eventLog.futureEventCount} events are dated in the future. '
          "One of your devices' clocks may be wrong.",
        ),
      if (eventLog.problems.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: _WarningText(
            '${eventLog.problems.length} lines could not be read and were '
            'skipped. The files were not changed.',
          ),
          children: [
            for (final problem in eventLog.problems)
              ListTile(dense: true, title: Text(problem.toString())),
          ],
        ),
    ];
  }
}

/// A line of warning text, in the theme's error colour.
class _WarningText extends StatelessWidget {
  const _WarningText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// Writes a moment as this device's local date and time, for example
/// `2026-11-17 21:04`.
String formatLocalDateTime(DateTime moment) {
  final local = moment.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
