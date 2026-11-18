// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's main screen: one day, from waking up to going to
/// bed, and that day's naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../sleep_actions.dart';
import '../sleep_episode.dart';
import '../sleep_log.dart';
import '../sleep_moment.dart';
import '../sleep_times.dart';
import 'sleep_form_screen.dart';
import 'sleep_widgets.dart';

/// The wake-up time suggested until the first wake-up is logged.
const ClockTime _firstWakeGuess = ClockTime(7, 0);

/// The bedtime suggested until the first bedtime is logged.
const ClockTime _firstBedGuess = ClockTime(23, 0);

/// Shows one day: when you woke up (left) and went to bed (right), how
/// long you slept the night before, and naps.
///
/// Before 05:00 the screen opens on the day before, because you have not
/// slept yet: going to bed at 01:00 still ends that day.
class SleepScreen extends StatefulWidget {
  /// Creates the screen.
  const SleepScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  /// The day being shown, at local midnight.
  DateTime _day = currentSleepDay(DateTime.now());

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final sleepToday = currentSleepDay(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep'),
        actions: [
          DayBar(
            day: _day,
            today: sleepToday,
            onChanged: (day) => setState(() => _day = day),
          ),
        ],
      ),
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: widget.appState.reloadEvents,
        child: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final log = SleepLog.of(widget.appState);
            final date = formatDate(_day);
            final wakeUp = log.wakeUpOn(date);
            final bedtime = log.bedtimeOf(date);
            final sleptBefore = log.sleepBefore(date);
            return ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (log.invalidCount > 0)
                  ProblemText(
                    '${log.invalidCount} entries in the data could not be '
                    'read and are not shown.',
                  ),
                SectionCard(
                  children: [
                    CardHeader(
                      icon: Icons.wb_sunny_outlined,
                      title: _day == sleepToday ? 'Today' : 'This day',
                    ),
                    const SizedBox(height: 8),
                    _DayEntry(
                      // A new key whenever the day or its saved times
                      // change, so the fields start from what is saved.
                      key: ValueKey(
                        '$date ${wakeUp?.id} ${wakeUp?.at} '
                        '${bedtime?.id} ${bedtime?.at}',
                      ),
                      appState: widget.appState,
                      day: _day,
                      wakeUp: wakeUp,
                      bedtime: bedtime,
                      wakeGuess:
                          log.latest(MomentKind.wokeUp)?.clock ??
                          _firstWakeGuess,
                      bedGuess:
                          log.latest(MomentKind.wentToBed)?.clock ??
                          _firstBedGuess,
                    ),
                    if (sleptBefore != null) ...[
                      const SizedBox(height: 12),
                      NoteText(
                        'Slept ${formatDuration(sleptBefore)} the night '
                        'before.',
                      ),
                    ],
                  ],
                ),
                SectionCard(
                  children: [
                    CardHeader(
                      icon: Icons.airline_seat_flat,
                      title: 'Naps',
                      action: HeaderAddButton(
                        onPressed: () => _open(
                          SleepFormScreen.addNap(
                            appState: widget.appState,
                            day: _day,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._buildNaps(log.napsOn(date)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildNaps(List<SleepEpisode> naps) {
    if (naps.isEmpty) {
      return [const NoteText('No naps on this day.')];
    }
    return [
      for (final nap in naps)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${nap.startClock} – ${nap.endClock}'),
          subtitle: Text(formatDuration(nap.duration)),
          trailing: IconButton(
            tooltip: 'Edit nap',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editNap(nap),
          ),
          onTap: () => _editNap(nap),
        ),
    ];
  }

  void _editNap(SleepEpisode nap) {
    _open(SleepFormScreen.editNap(appState: widget.appState, episode: nap));
  }
}

/// The day's two moments, each a date-and-time field, and one Save.
///
/// Woke up starts at what is saved, or the usual wake-up time. Went to
/// bed starts at what is saved, or "Not set", so saving in the morning
/// never records a bedtime that has not happened.
class _DayEntry extends StatefulWidget {
  const _DayEntry({
    super.key,
    required this.appState,
    required this.day,
    required this.wakeUp,
    required this.bedtime,
    required this.wakeGuess,
    required this.bedGuess,
  });

  final AppState appState;
  final DateTime day;
  final SleepMoment? wakeUp;
  final SleepMoment? bedtime;
  final ClockTime wakeGuess;
  final ClockTime bedGuess;

  @override
  State<_DayEntry> createState() => _DayEntryState();
}

class _DayEntryState extends State<_DayEntry> {
  late DateTime? _wokeUp = widget.wakeUp == null
      ? wakeUpMoment(widget.day, widget.wakeGuess)
      : localDateTimeOf(widget.wakeUp!.at);
  late DateTime? _wentToBed = widget.bedtime == null
      ? null
      : localDateTimeOf(widget.bedtime!.at);
  String? _problem;

  /// Where the bedtime pickers start: the usual bedtime, after midnight
  /// if it is earlier on the clock than waking up.
  DateTime get _bedSuggestion {
    final wokeUp = _wokeUp;
    return bedtimeMoment(
      widget.day,
      widget.bedGuess,
      wokeUp == null ? null : ClockTime(wokeUp.hour, wokeUp.minute),
    );
  }

  bool get _hasSomethingSaved =>
      widget.wakeUp != null || widget.bedtime != null;

  Future<void> _save() async {
    final problem = checkDayTimes(_wokeUp, _wentToBed);
    setState(() => _problem = problem);
    if (problem != null) {
      return;
    }
    final actions = SleepActions(widget.appState);
    await saveOrShowError(context, () async {
      await _saveOne(actions, MomentKind.wokeUp, widget.wakeUp, _wokeUp);
      await _saveOne(actions, MomentKind.wentToBed, widget.bedtime, _wentToBed);
    });
  }

  /// Records [value], or changes [saved] to it. Does nothing if there is
  /// no value, or it is the same as what is saved.
  Future<void> _saveOne(
    SleepActions actions,
    MomentKind kind,
    SleepMoment? saved,
    DateTime? value,
  ) async {
    if (value == null) {
      return;
    }
    if (saved == null) {
      await actions.recordMoment(kind: kind, day: widget.day, at: value);
      return;
    }
    if (localDateTimeOf(saved.at) != value) {
      await actions.changeMoment(saved, value);
    }
  }

  Future<void> _clear() async {
    final actions = SleepActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final wakeUp = widget.wakeUp;
    final bedtime = widget.bedtime;
    final saved = [if (wakeUp != null) wakeUp, if (bedtime != null) bedtime];
    final cleared = await saveOrShowError(context, () async {
      for (final moment in saved) {
        await actions.deleteMoment(moment);
      }
    });
    if (!cleared) {
      return;
    }
    showUndoMessage(
      messenger,
      message: 'Cleared this day\'s times.',
      onUndo: () async {
        for (final moment in saved) {
          await actions.restoreMoment(moment);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DateTimeField(
                label: MomentKind.wokeUp.label,
                value: _wokeUp,
                suggestion: wakeUpMoment(widget.day, widget.wakeGuess),
                onChanged: (moment) => setState(() {
                  _wokeUp = moment;
                  _problem = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DateTimeField(
                label: MomentKind.wentToBed.label,
                value: _wentToBed,
                suggestion: _bedSuggestion,
                onChanged: (moment) => setState(() {
                  _wentToBed = moment;
                  _problem = null;
                }),
              ),
            ),
          ],
        ),
        if (_problem != null) ...[
          const SizedBox(height: 8),
          ProblemText(_problem!),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
        if (_hasSomethingSaved)
          DeleteButton(label: 'Clear this day', onPressed: _clear),
      ],
    );
  }
}
