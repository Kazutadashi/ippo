// SPDX-License-Identifier: GPL-3.0-or-later

/// The part of the settings screen that lists devices and when each was
/// last seen, plus any problems found while reading the data.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../events/event_log.dart';
import '../widgets/section_card.dart';

/// Shows every device that has written events, with the time of its
/// latest event, so the user can tell whether sync has caught up. (The
/// Refresh button is in the card's header, on the settings screen.)
class DevicesSection extends StatefulWidget {
  /// Creates the section.
  const DevicesSection({super.key, required this.appState});

  /// The app-wide state to show.
  final AppState appState;

  @override
  State<DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<DevicesSection> {
  /// Whether the list of unreadable lines is open.
  bool _isShowingProblems = false;

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final eventLog = appState.eventLog;
    if (appState.dataFolder == null) {
      return const NoteText('Choose a data folder first.');
    }
    if (eventLog == null) {
      return const NoteText('Reading the data folder…');
    }

    final thisDeviceId = appState.settings?.deviceId;
    final devices = eventLog.lastSeenByDevice.values.toList()
      // Most recently seen first.
      ..sort(
        (first, second) =>
            second.latestRecordedAtUtc.compareTo(first.latestRecordedAtUtc),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (devices.isEmpty) const NoteText('No events yet, from any device.'),
        for (final device in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoText(
                  label: device.deviceId == thisDeviceId
                      ? 'This device'
                      : 'Other device',
                  text: device.deviceName,
                ),
                NoteText(
                  'Last event '
                  '${formatLocalDateTime(device.latestRecordedAtUtc)}',
                ),
              ],
            ),
          ),
        NoteText('${eventLog.events.length} events in total.'),
        ..._warnings(eventLog),
      ],
    );
  }

  /// Warnings the user should know about. Nothing is ever hidden: every
  /// skipped line can be listed.
  List<Widget> _warnings(EventLog eventLog) {
    final problemCount = eventLog.problems.length;
    return [
      if (eventLog.newerVersionEventCount > 0)
        _spaced(
          ProblemText(
            '${eventLog.newerVersionEventCount} events were written by a '
            'newer version of Ippo. Update this app to see them.',
          ),
        ),
      if (eventLog.futureEventCount > 0)
        _spaced(
          ProblemText(
            '${eventLog.futureEventCount} events are dated in the future. '
            "One of your devices' clocks may be wrong.",
          ),
        ),
      if (problemCount > 0) ...[
        _spaced(
          ProblemText(
            problemCount == 1
                ? '1 line could not be read and was skipped. The file was '
                      'not changed.'
                : '$problemCount lines could not be read and were skipped. '
                      'The files were not changed.',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            // No inner padding, so the button lines up with the text.
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () =>
                setState(() => _isShowingProblems = !_isShowingProblems),
            child: Text(_isShowingProblems ? 'Hide details' : 'Show details'),
          ),
        ),
        if (_isShowingProblems)
          for (final problem in eventLog.problems)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: NoteText(problem.toString()),
            ),
      ],
    ];
  }
}

/// Puts a little space above a warning.
Widget _spaced(Widget child) =>
    Padding(padding: const EdgeInsets.only(top: 12), child: child);

/// Writes a moment as this device's local date and time, for example
/// `2026-11-17 21:04`.
String formatLocalDateTime(DateTime moment) {
  final local = moment.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
