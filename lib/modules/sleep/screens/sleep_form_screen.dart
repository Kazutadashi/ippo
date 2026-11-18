// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding, changing or deleting a nap.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../sleep_actions.dart';
import '../sleep_episode.dart';
import '../sleep_times.dart';
import 'sleep_widgets.dart';

/// The form for one nap: its start and end times.
class SleepFormScreen extends StatefulWidget {
  /// Creates the form for a new nap on [day].
  const SleepFormScreen.addNap({
    super.key,
    required this.appState,
    required DateTime this.day,
  }) : episode = null;

  /// Creates the form for changing the nap [episode].
  const SleepFormScreen.editNap({
    super.key,
    required this.appState,
    required SleepEpisode this.episode,
  }) : day = null;

  /// The app-wide state.
  final AppState appState;

  /// The day of the new nap, when adding.
  final DateTime? day;

  /// The nap being changed, when editing.
  final SleepEpisode? episode;

  @override
  State<SleepFormScreen> createState() => _SleepFormScreenState();
}

class _SleepFormScreenState extends State<SleepFormScreen> {
  late ClockTime _start = widget.episode?.startClock ?? _napStartGuess();
  late ClockTime _end = widget.episode?.endClock ?? _napEndGuess();

  /// A new nap starts an hour ago and ends now: often about right.
  static ClockTime _napStartGuess() {
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return ClockTime(hourAgo.hour, hourAgo.minute);
  }

  static ClockTime _napEndGuess() {
    final now = DateTime.now();
    return ClockTime(now.hour, now.minute);
  }

  /// The nap's day.
  DateTime get _day => widget.day ?? parseDate(widget.episode!.date)!;

  SleepPeriod _period() {
    return napPeriod(_day, _start, _end);
  }

  Future<void> _save() async {
    final period = _period();
    if (checkSleepPeriod(period) != null) {
      return;
    }
    final actions = SleepActions(widget.appState);
    final episode = widget.episode;
    final saved = await saveOrShowError(context, () {
      if (episode == null) {
        return actions.recordSleep(
          day: _day,
          kind: SleepKind.nap,
          period: period,
        );
      }
      return actions.changeSleep(episode.id, period);
    });
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final episode = widget.episode!;
    final actions = SleepActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteSleep(episode.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Nap deleted.',
      onUndo: () => actions.restoreSleep(episode.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = _period();
    final problem = checkSleepPeriod(period);
    return Scaffold(
      appBar: AppBar(title: const Text('Nap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TimeField(
                  label: 'Start',
                  time: _start,
                  onChanged: (time) => setState(() => _start = time),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TimeField(
                  label: 'End',
                  time: _end,
                  onChanged: (time) => setState(() => _end = time),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (problem == null)
            NoteText('${formatDuration(period.duration)} of sleep')
          else
            ProblemText(problem),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: problem == null ? _save : null,
            child: const Text('Save'),
          ),
          if (widget.episode != null)
            DeleteButton(label: 'Delete this nap', onPressed: _delete),
        ],
      ),
    );
  }
}
