// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding, changing or deleting a nap.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../sleep_actions.dart';
import '../nap.dart';
import '../sleep_times.dart';
import '../../../core/widgets/time_fields.dart';

/// The form for one nap: its start and end times.
class NapFormScreen extends StatefulWidget {
  /// Creates the form for a new nap on [day].
  const NapFormScreen.addNap({
    super.key,
    required this.appState,
    required DateTime this.day,
  }) : nap = null;

  /// Creates the form for changing the nap [nap].
  const NapFormScreen.editNap({
    super.key,
    required this.appState,
    required Nap this.nap,
  }) : day = null;

  /// The app-wide state.
  final AppState appState;

  /// The day of the new nap, when adding.
  final DateTime? day;

  /// The nap being changed, when editing.
  final Nap? nap;

  @override
  State<NapFormScreen> createState() => _NapFormScreenState();
}

class _NapFormScreenState extends State<NapFormScreen> {
  late ClockTime _start = widget.nap?.startClock ?? _napStartGuess();
  late ClockTime _end = widget.nap?.endClock ?? _napEndGuess();

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
  DateTime get _day => widget.day ?? parseDate(widget.nap!.date)!;

  SleepPeriod _period() {
    return napPeriod(_day, _start, _end);
  }

  Future<void> _save() async {
    final period = _period();
    if (checkSleepPeriod(period) != null) {
      return;
    }
    final actions = SleepActions(widget.appState);
    final nap = widget.nap;
    final saved = await saveOrShowError(context, () {
      if (nap == null) {
        return actions.recordNap(day: _day, period: period);
      }
      return actions.changeNap(nap.id, period);
    });
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final nap = widget.nap!;
    final actions = SleepActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteNap(nap.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Nap deleted.',
      onUndo: () => actions.restoreNap(nap.id),
    );
  }

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => '$_start $_end';

  @override
  Widget build(BuildContext context) {
    final period = _period();
    final problem = checkSleepPeriod(period);
    return DiscardGuard(
      snapshot: _snapshot,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close without saving',
            icon: const Icon(Icons.close),
            // Through the discard guard, like the back button.
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Nap'),
          actions: [
            AppBarSaveButton(onPressed: problem == null ? _save : null),
          ],
        ),
        body: ListView(
          padding: belowNavigationBar(context, const EdgeInsets.all(16)),
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
            if (widget.nap != null)
              DeleteButton(label: 'Delete this nap', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}
