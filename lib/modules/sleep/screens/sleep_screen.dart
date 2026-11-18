// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's main screen: one day, from waking up to going to
/// bed, and that day's naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../sleep_actions.dart';
import '../sleep_episode.dart';
import '../sleep_log.dart';
import '../sleep_moment.dart';
import '../sleep_times.dart';
import 'moment_form_screen.dart';
import 'sleep_form_screen.dart';
import 'sleep_widgets.dart';

/// The wake-up time shown until the first wake-up is logged.
const ClockTime _firstWakeGuess = ClockTime(7, 0);

/// The bedtime shown until the first bedtime is logged.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final log = SleepLog.fromEvents(
            widget.appState.eventLog?.events ?? [],
          );
          final date = formatDate(_day);
          final wakeUp = log.wakeUpOn(date);
          final bedtime = log.bedtimeOf(date);
          final sleptBefore = log.sleepBefore(date);
          final wakeClock =
              wakeUp?.clock ??
              log.latest(MomentKind.wokeUp)?.clock ??
              _firstWakeGuess;
          final sleepToday = currentSleepDay(DateTime.now());
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DayBar(
                day: _day,
                today: sleepToday,
                onChanged: (day) => setState(() => _day = day),
              ),
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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _MomentColumn(
                            key: ValueKey('wake-$date'),
                            appState: widget.appState,
                            kind: MomentKind.wokeUp,
                            day: _day,
                            moment: wakeUp,
                            guess: wakeClock,
                            wokeUp: null,
                            onEdit: _open,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MomentColumn(
                            key: ValueKey('bed-$date'),
                            appState: widget.appState,
                            kind: MomentKind.wentToBed,
                            day: _day,
                            moment: bedtime,
                            guess:
                                log.latest(MomentKind.wentToBed)?.clock ??
                                _firstBedGuess,
                            wokeUp: wakeClock,
                            onEdit: _open,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sleptBefore != null) ...[
                    const SizedBox(height: 16),
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

/// One side of the day: the wake-up or the bedtime.
///
/// Once logged, it shows as information with an Edit button. Before
/// that, it is a time field (starting at the last logged time) with its
/// own Save button. Under either, the calendar day is written out, so a
/// bedtime after midnight is never ambiguous.
class _MomentColumn extends StatefulWidget {
  const _MomentColumn({
    super.key,
    required this.appState,
    required this.kind,
    required this.day,
    required this.moment,
    required this.guess,
    required this.wokeUp,
    required this.onEdit,
  });

  final AppState appState;
  final MomentKind kind;
  final DateTime day;

  /// The logged moment, or null if not logged yet.
  final SleepMoment? moment;

  /// The time to start the field with.
  final ClockTime guess;

  /// The day's wake-up time, for working out a bedtime's calendar day.
  final ClockTime? wokeUp;

  /// Opens a screen (here, the form for changing the moment).
  final ValueChanged<Widget> onEdit;

  @override
  State<_MomentColumn> createState() => _MomentColumnState();
}

class _MomentColumnState extends State<_MomentColumn> {
  late ClockTime _time = widget.guess;
  String? _problem;

  DateTime _momentAt(ClockTime time) {
    return widget.kind == MomentKind.wentToBed
        ? bedtimeMoment(widget.day, time, widget.wokeUp)
        : wakeUpMoment(widget.day, time);
  }

  Future<void> _save() async {
    final isSameAsWakeUp =
        widget.kind == MomentKind.wentToBed && _time == widget.wokeUp;
    if (isSameAsWakeUp) {
      setState(() => _problem = 'Same time as waking up.');
      return;
    }
    setState(() => _problem = null);
    await saveOrShowError(
      context,
      () => SleepActions(
        widget.appState,
      ).recordMoment(kind: widget.kind, day: widget.day, at: _momentAt(_time)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    if (moment != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoValue(label: widget.kind.label, value: '${moment.clock}'),
          const SizedBox(height: 4),
          NoteText(describeMomentDay(_localMoment(moment), widget.day)),
          const Spacer(),
          TextButton.icon(
            // No inner padding, so the button lines up with the text.
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => widget.onEdit(
              MomentFormScreen(
                appState: widget.appState,
                moment: moment,
                wokeUp: widget.wokeUp,
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeField(
          label: widget.kind.label,
          time: _time,
          onChanged: (time) => setState(() {
            _time = time;
            _problem = null;
          }),
        ),
        const SizedBox(height: 4),
        if (_problem == null)
          NoteText(describeMomentDay(_momentAt(_time), widget.day))
        else
          ProblemText(_problem!),
        const Spacer(),
        const SizedBox(height: 8),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  /// The moment's calendar day, read from the stored text, which keeps
  /// the local date where it was recorded.
  DateTime _localMoment(SleepMoment moment) => parseDate(moment.calendarDate)!;
}
