// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's main screen: the night that ended on one day, and
/// that day's naps.
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
import '../sleep_times.dart';
import 'sleep_form_screen.dart';
import 'sleep_widgets.dart';

/// The bedtime shown until the first night is logged.
const ClockTime _firstBedGuess = ClockTime(23, 0);

/// The wake-up time shown until the first night is logged.
const ClockTime _firstWakeGuess = ClockTime(7, 0);

/// Shows one day's sleep: the night that ended that morning, and naps.
class SleepScreen extends StatefulWidget {
  /// Creates the screen.
  const SleepScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  /// The day being shown, at local midnight. Starts at today.
  DateTime _day = today();

  void _edit(SleepEpisode episode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            SleepFormScreen.edit(appState: widget.appState, episode: episode),
      ),
    );
  }

  void _addNap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            SleepFormScreen.addNap(appState: widget.appState, day: _day),
      ),
    );
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
          final night = log.nightOn(date);
          final lastNight = log.lastNight();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DayBar(day: _day, onChanged: (day) => setState(() => _day = day)),
              if (log.invalidCount > 0)
                ProblemText(
                  '${log.invalidCount} entries in the data could not be '
                  'read and are not shown.',
                ),
              SectionCard(
                children: [
                  CardHeader(
                    icon: Icons.bedtime,
                    title: _day == today() ? 'Last night' : 'Night',
                    action: night == null
                        ? null
                        : HeaderEditButton(onPressed: () => _edit(night)),
                  ),
                  const SizedBox(height: 12),
                  if (night == null)
                    _NightEntry(
                      // A new key per day starts the entry fresh.
                      key: ValueKey(date),
                      appState: widget.appState,
                      wakeDay: _day,
                      bedGuess: lastNight?.startClock ?? _firstBedGuess,
                      wakeGuess: lastNight?.endClock ?? _firstWakeGuess,
                    )
                  else
                    _NightSummary(night: night),
                ],
              ),
              SectionCard(
                children: [
                  CardHeader(
                    icon: Icons.airline_seat_flat,
                    title: 'Naps',
                    action: HeaderAddButton(onPressed: _addNap),
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
            onPressed: () => _edit(nap),
          ),
          onTap: () => _edit(nap),
        ),
    ];
  }
}

/// A logged night, shown as information. (Its Edit button is in the
/// card's header.)
class _NightSummary extends StatelessWidget {
  const _NightSummary({required this.night});

  final SleepEpisode night;

  @override
  Widget build(BuildContext context) {
    return InfoRow(
      values: [
        InfoValue(label: 'Went to bed', value: '${night.startClock}'),
        InfoValue(label: 'Woke up', value: '${night.endClock}'),
        InfoValue(label: 'Slept', value: formatDuration(night.duration)),
      ],
    );
  }
}

/// Entering a night right on the main screen: two time fields and Save.
///
/// Both times start at last night's, so a usual night is one tap.
class _NightEntry extends StatefulWidget {
  const _NightEntry({
    super.key,
    required this.appState,
    required this.wakeDay,
    required this.bedGuess,
    required this.wakeGuess,
  });

  final AppState appState;
  final DateTime wakeDay;
  final ClockTime bedGuess;
  final ClockTime wakeGuess;

  @override
  State<_NightEntry> createState() => _NightEntryState();
}

class _NightEntryState extends State<_NightEntry> {
  late ClockTime _bed = widget.bedGuess;
  late ClockTime _woke = widget.wakeGuess;

  Future<void> _save() async {
    final period = nightPeriod(widget.wakeDay, _bed, _woke);
    if (checkSleepPeriod(period) != null) {
      return;
    }
    await saveOrShowError(
      context,
      () => SleepActions(
        widget.appState,
      ).recordSleep(day: widget.wakeDay, kind: SleepKind.night, period: period),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = nightPeriod(widget.wakeDay, _bed, _woke);
    final problem = checkSleepPeriod(period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TimeField(
                label: 'Went to bed',
                time: _bed,
                onChanged: (time) => setState(() => _bed = time),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TimeField(
                label: 'Woke up',
                time: _woke,
                onChanged: (time) => setState(() => _woke = time),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (problem == null)
          NoteText('${formatDuration(period.duration)} of sleep')
        else
          ProblemText(problem),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: problem == null ? _save : null,
          child: const Text('Save night'),
        ),
      ],
    );
  }
}
