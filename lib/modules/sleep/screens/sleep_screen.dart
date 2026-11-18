// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module's main screen: the night that ended on one day, and
/// that day's naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/day_bar.dart';
import '../sleep_actions.dart';
import '../sleep_episode.dart';
import '../sleep_log.dart';
import '../sleep_times.dart';
import 'sleep_form_screen.dart';
import 'time_button.dart';

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
          final night = log.nightOn(date);
          final lastNight = log.lastNight();
          final naps = log.napsOn(date);
          final textTheme = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DayBar(day: _day, onChanged: (day) => setState(() => _day = day)),
              if (log.invalidCount > 0)
                Text(
                  '${log.invalidCount} entries in the data could not be '
                  'read and are not shown.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Night', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
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
                        _EpisodeTile(
                          episode: night,
                          onTap: () => _open(
                            SleepFormScreen.edit(
                              appState: widget.appState,
                              episode: night,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Naps', style: textTheme.titleMedium),
                      if (naps.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('No naps on this day.'),
                        ),
                      for (final nap in naps)
                        _EpisodeTile(
                          episode: nap,
                          onTap: () => _open(
                            SleepFormScreen.edit(
                              appState: widget.appState,
                              episode: nap,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _open(
                          SleepFormScreen.addNap(
                            appState: widget.appState,
                            day: _day,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add nap'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Entering a night right on the main screen: bedtime, wake-up, Save.
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
  String? _problem;

  Future<void> _save() async {
    final period = nightPeriod(widget.wakeDay, _bed, _woke);
    final problem = checkSleepPeriod(period);
    setState(() => _problem = problem);
    if (problem != null) {
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
    final isValid = checkSleepPeriod(period) == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TimeButton(
              label: 'Bed',
              icon: Icons.bedtime_outlined,
              time: _bed,
              onChanged: (time) => setState(() => _bed = time),
            ),
            TimeButton(
              label: 'Woke',
              icon: Icons.wb_sunny_outlined,
              time: _woke,
              onChanged: (time) => setState(() => _woke = time),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isValid) Text(formatDuration(period.duration)),
        if (_problem != null)
          Text(
            _problem!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _save, child: const Text('Save night')),
      ],
    );
  }
}

/// A logged night or nap; tapping it opens it for changing.
class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.onTap});

  final SleepEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        episode.kind == SleepKind.night
            ? Icons.bedtime
            : Icons.airline_seat_flat,
      ),
      title: Text('${episode.startClock} → ${episode.endClock}'),
      subtitle: Text(formatDuration(episode.duration)),
      trailing: const Icon(Icons.edit_outlined),
      onTap: onTap,
    );
  }
}
