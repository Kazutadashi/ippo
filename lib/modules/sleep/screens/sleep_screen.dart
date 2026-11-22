// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's main screen: one day, from waking up to going to
/// bed, and that day's naps.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/follows_today.dart';
import '../../../core/widgets/moon_icon.dart';
import '../../../core/widgets/section_card.dart';
import '../sleep_actions.dart';
import '../nap.dart';
import '../sleep_log.dart';
import '../sleep_moment.dart';
import '../sleep_times.dart';
import 'nap_form_screen.dart';
import '../../../core/widgets/time_fields.dart';
import '../../../core/widgets/value_text.dart';
import '../../../core/widgets/tab_app_bar.dart';
import '../time_span_bar.dart';

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

class _SleepScreenState extends State<SleepScreen> with FollowsToday {
  @override
  AppState get dayState => widget.appState;

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: tabAppBar(
        context,
        title: const Text('Sleep'),
        day: shownDay,
        onDayChanged: showDay,
      ),
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: widget.appState.reloadEvents,
        child: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final log = SleepLog.of(widget.appState);
            final date = formatDate(shownDay);
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
                // The night before the day, large: the number that
                // matters most here.
                _LastNightCard(
                  slept: sleptBefore,
                  bedtime: log.bedtimeOf(formatDate(addDays(shownDay, -1))),
                  wakeUp: wakeUp,
                  average: log.averageSleepBefore(shownDay),
                  isToday: showsToday,
                ),
                SectionCard(
                  children: [
                    CardHeader(
                      icon: Icons.wb_sunny_outlined,
                      title: showsToday ? 'Today' : 'This day',
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
                      day: shownDay,
                      wakeUp: wakeUp,
                      bedtime: bedtime,
                      wakeGuess:
                          log.latest(MomentKind.wokeUp)?.clock ??
                          _firstWakeGuess,
                      bedGuess:
                          log.latest(MomentKind.wentToBed)?.clock ??
                          _firstBedGuess,
                    ),
                  ],
                ),
                // A new nap: in the right half, where the other tabs have
                // their add buttons.
                const SizedBox(height: Spacing.small),
                Row(
                  children: [
                    const Spacer(),
                    const SizedBox(width: Spacing.small),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _open(
                          NapFormScreen.addNap(
                            appState: widget.appState,
                            day: shownDay,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add nap'),
                      ),
                    ),
                  ],
                ),
                // The day's naps, only when there are any.
                if (log.napsOn(date).isNotEmpty)
                  SectionCard(
                    children: [
                      const CardHeader(
                        icon: Icons.airline_seat_flat,
                        title: 'Naps',
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

  List<Widget> _buildNaps(List<Nap> naps) {
    return [
      for (final nap in naps)
        ListTile(
          contentPadding: EdgeInsets.zero,
          // The nap's length first and large, with an icon; when it was,
          // under it.
          leading: _NapIcon(),
          title: Text(
            formatDuration(nap.duration),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text('${nap.startClock.shown} – ${nap.endClock.shown}'),
          trailing: IconButton(
            tooltip: 'Edit nap',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editNap(nap),
          ),
          onTap: () => _editNap(nap),
        ),
    ];
  }

  void _editNap(Nap nap) {
    _open(NapFormScreen.editNap(appState: widget.appState, nap: nap));
  }
}

/// The day's two moments, each a date-and-time field, and one Save.
///
/// Woke up starts at what is saved, or the usual wake-up time. Went to
/// bed starts at what is saved, or "Not set", so saving in the morning
/// never records a bedtime that has not happened.
/// From this hour on, the day entry offers "Going to bed now".
const int _eveningHour = 18;

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
    return bedtimeMoment(widget.day, widget.bedGuess, _wokeClock);
  }

  bool get _hasSomethingSaved =>
      widget.wakeUp != null || widget.bedtime != null;

  /// The wake-up clock time, for working out the bedtime's date.
  ClockTime? get _wokeClock {
    final wokeUp = _wokeUp;
    return wokeUp == null ? null : ClockTime(wokeUp.hour, wokeUp.minute);
  }

  /// Whether the fields hold something that is not saved yet. Then the
  /// button says Save; otherwise it says Saved, which doubles as the
  /// sign that saving worked.
  bool get _hasChanges {
    bool differs(SleepMoment? saved, DateTime? value) =>
        value != null && (saved == null || localDateTimeOf(saved.at) != value);
    return differs(widget.wakeUp, _wokeUp) ||
        differs(widget.bedtime, _wentToBed);
  }

  /// Whether the wake-up shown is only the usual time, not saved and not
  /// changed by the user.
  bool get _wakeIsSuggestion =>
      widget.wakeUp == null &&
      _wokeUp == wakeUpMoment(widget.day, widget.wakeGuess);

  /// The one-tap button for right now, if there is one: "Woke up now"
  /// until the wake-up is saved, then, in the evening and night (from
  /// [_eveningHour] until the day ends at [dayStartHour]), "Going to bed
  /// now" until the bedtime is. Only for today: other days are logged
  /// after the fact.
  MomentKind? get _nowKind {
    if (widget.day != today()) {
      return null;
    }
    if (widget.wakeUp == null) {
      return MomentKind.wokeUp;
    }
    final hour = DateTime.now().hour;
    final isEvening = hour >= _eveningHour || hour < dayStartHour;
    if (widget.bedtime == null && isEvening) {
      return MomentKind.wentToBed;
    }
    return null;
  }

  /// Saves [kind] as happening now, to the minute, in one tap: no time
  /// to pick, which is the common case in the morning and at night.
  Future<void> _saveNow(MomentKind kind) async {
    final now = DateTime.now();
    final moment = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    HapticFeedback.selectionClick();
    await saveOrShowError(
      context,
      () =>
          SleepActions(widget.appState)
              .recordMoment(kind: kind, day: widget.day, at: moment),
    );
  }

  Future<void> _save() async {
    final problem = checkDayTimes(_wokeUp, _wentToBed);
    setState(() => _problem = problem);
    if (problem != null) {
      return;
    }
    final actions = SleepActions(widget.appState);
    HapticFeedback.selectionClick();
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
                isSuggestion: _wakeIsSuggestion,
                suggestion: wakeUpMoment(widget.day, widget.wakeGuess),
                momentFor: (time) => wakeUpMoment(widget.day, time),
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
                momentFor: (time) =>
                    bedtimeMoment(widget.day, time, _wokeClock),
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
        if (_nowKind != null) ...[
          FilledButton.tonalIcon(
            onPressed: () => _saveNow(_nowKind!),
            icon: Icon(
              _nowKind == MomentKind.wokeUp
                  ? Icons.wb_sunny_outlined
                  : Icons.bedtime_outlined,
            ),
            label: Text(
              _nowKind == MomentKind.wokeUp
                  ? 'Woke up now'
                  : 'Going to bed now',
            ),
          ),
        ],
        if (_hasChanges) ...[
          if (_nowKind != null) const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
        // A quiet last row: "Saved" when nothing is waiting to be saved
        // (the sign that saving worked), and Clear on the right.
        if (!_hasChanges || _hasSomethingSaved)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.tight),
            // Each side may wrap its words with very large text, rather
            // than push the other off the card.
            child: Row(
              mainAxisAlignment: _hasChanges
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!_hasChanges) const Flexible(child: _SavedNote()),
                if (_hasSomethingSaved)
                  Flexible(
                    child: TextButton(
                      onPressed: _clear,
                      child: Text(
                        'Clear this day',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A small "✓ Saved", in grey: everything shown is saved.
class _SavedNote extends StatelessWidget {
  const _SavedNote();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 18, color: muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Saved',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Last night, large: the hours slept with a moon, the night as a bar
/// from bedtime to waking up, and the nightly average under it.
class _LastNightCard extends StatelessWidget {
  const _LastNightCard({
    required this.slept,
    required this.bedtime,
    required this.wakeUp,
    required this.average,
    required this.isToday,
  });

  final Duration? slept;
  final SleepMoment? bedtime;
  final SleepMoment? wakeUp;
  final Duration? average;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final slept = this.slept;
    final bedtime = this.bedtime;
    final wakeUp = this.wakeUp;
    final average = this.average;
    return SectionCard(
      children: [
        CardHeader(
          iconWidget: const MoonIcon(),
          title: isToday ? 'Last night' : 'The night before',
        ),
        if (slept == null)
          const NoteText('Log the bedtime and the wake-up below to see it.')
        else ...[
          // The hours slept, large: the moon is in the card's header.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ValueText(
              formatDuration(slept),
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              unitStyle: textTheme.titleMedium?.copyWith(color: muted),
            ),
          ),
          if (bedtime != null && wakeUp != null) ...[
            const SizedBox(height: Spacing.medium),
            TimeSpanBar(
              start: bedtime.clock,
              end: wakeUp.clock,
              trackStartHour: TimeSpanBar.nightStartHour,
              trackHours: TimeSpanBar.nightHours,
              startLabel: bedtime.clock.shown,
              endLabel: wakeUp.clock.shown,
              description:
                  'Bed at ${bedtime.clock.shown}, woke at '
                  '${wakeUp.clock.shown}',
            ),
          ],
        ],
        if (average != null) ...[
          const SizedBox(height: Spacing.medium),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Avg (7 nights)',
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
              Text(formatDuration(average), style: textTheme.titleSmall),
            ],
          ),
        ],
      ],
    );
  }
}

/// A nap's icon: a lying figure on a soft circle in the accent colour.
class _NapIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.airline_seat_flat, color: colors.primary, size: 22),
    );
  }
}
