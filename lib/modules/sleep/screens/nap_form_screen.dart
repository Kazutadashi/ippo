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
import '../../../core/widgets/value_text.dart';
import '../time_span_bar.dart';

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

/// The nap lengths offered as one-tap choices, in minutes: two rows of
/// three.
const List<int> _napLengths = [15, 20, 30, 45, 60, 90];

/// The track a nap is drawn on: the waking day, 06:00 to midnight.
const int _dayTrackStartHour = 6;

/// How many hours that track spans.
const int _dayTrackHours = 18;

class _NapFormScreenState extends State<NapFormScreen> {
  /// The nap's day: the day shown when adding, the nap's own when
  /// changing it. It can be changed, to move a nap logged on the wrong
  /// day.
  late DateTime _day = widget.day ?? parseDate(widget.nap!.date)!;

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

  /// Sets the start [minutes] before the end, which stays: a nap is
  /// mostly logged just after waking, when only its length is unknown.
  void _setLength(int minutes) {
    final end = DateTime(2000, 1, 1, _end.hour, _end.minute);
    final start = end.subtract(Duration(minutes: minutes));
    setState(() => _start = ClockTime(start.hour, start.minute));
  }

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
      return actions.changeNap(
        nap.id,
        period,
        date: formatDate(_day) == nap.date ? null : _day,
      );
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
  String _snapshot() => '$_day $_start $_end';

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
          title: Text(widget.nap == null ? 'New nap' : 'Edit nap'),
          actions: [
            AppBarSaveButton(onPressed: problem == null ? _save : null),
          ],
        ),
        body: ListView(
          padding: belowNavigationBar(
            context,
            const EdgeInsets.fromLTRB(16, 8, 16, 24),
          ),
          children: [
            // When: the day, then the start and the end side by side.
            SectionCard(
              children: [
                const CardHeader(icon: Icons.airline_seat_flat, title: 'When'),
                DateField(
                  label: 'Day',
                  day: _day,
                  onChanged: (day) => setState(() => _day = day),
                ),
                const SizedBox(height: Spacing.medium),
                Row(
                  children: [
                    Expanded(
                      child: TimeField(
                        label: 'Start',
                        time: _start,
                        onChanged: (time) => setState(() => _start = time),
                      ),
                    ),
                    const SizedBox(width: Spacing.medium),
                    Expanded(
                      child: TimeField(
                        label: 'End',
                        time: _end,
                        onChanged: (time) => setState(() => _end = time),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // How long: the length large, the nap on the day's clock, and
            // the usual lengths as one-tap choices.
            SectionCard(
              children: [
                const CardHeader(icon: Icons.timelapse, title: 'Length'),
                if (problem == null) ...[
                  ValueText(
                    formatDuration(period.duration),
                    style: Theme.of(context).textTheme.headlineMedium,
                    unitStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: Spacing.small),
                  TimeSpanBar(
                    start: _start,
                    end: _end,
                    trackStartHour: _dayTrackStartHour,
                    trackHours: _dayTrackHours,
                    startLabel: _start.shown,
                    endLabel: _end.shown,
                    description: 'Nap from ${_start.shown} to ${_end.shown}',
                  ),
                ] else
                  ProblemText(problem),
                const SizedBox(height: Spacing.medium),
                _LengthChoices(
                  selectedMinutes: problem == null
                      ? period.duration.inMinutes
                      : null,
                  onSelected: _setLength,
                ),
                const SizedBox(height: Spacing.small),
                const NoteText('A length keeps the end and moves the start.'),
              ],
            ),
            if (widget.nap != null)
              DeleteButton(label: 'Delete this nap', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}

/// The usual nap lengths as a grid of equal buttons, three to a row, so
/// they line up however long their labels are. The chosen one is filled
/// in the accent tint; [selectedMinutes] is null when none is.
class _LengthChoices extends StatelessWidget {
  const _LengthChoices({
    required this.selectedMinutes,
    required this.onSelected,
  });

  final int? selectedMinutes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const perRow = 3;
    return Column(
      children: [
        for (var start = 0; start < _napLengths.length; start += perRow) ...[
          if (start > 0) const SizedBox(height: Spacing.small),
          Row(
            children: [
              for (var index = start; index < start + perRow; index++) ...[
                if (index > start) const SizedBox(width: Spacing.small),
                Expanded(child: _choice(context, _napLengths[index])),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _choice(BuildContext context, int minutes) {
    // All in minutes ("90 min", not "1 h 30 min"): one short line each,
    // and easy to compare at a glance.
    final label = Text('$minutes min', maxLines: 1);
    if (minutes == selectedMinutes) {
      return Semantics(
        selected: true,
        child: FilledButton.tonal(
          onPressed: () => onSelected(minutes),
          child: label,
        ),
      );
    }
    return OutlinedButton(onPressed: () => onSelected(minutes), child: label);
  }
}
