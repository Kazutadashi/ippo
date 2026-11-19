// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you woke up and went to bed each day, and
/// naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/clock_time.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'screens/sleep_screen.dart';
import 'nap.dart';
import 'time_span_bar.dart';
import 'sleep_moment.dart';
import 'sleep_log.dart';

/// The sleep module, as seen by the core app.
class SleepModule extends IppoModule {
  /// Creates the module.
  const SleepModule();

  @override
  String get moduleName => sleepModuleName;

  @override
  String get title => 'Sleep';

  @override
  IconData get icon => Icons.bedtime;

  /// Two tiles: the sleep before today (with any naps), and how long
  /// you have been awake.
  @override
  List<TodayFact> dayFacts(AppState appState, DateTime day, DateTime now) {
    final log = SleepLog.of(appState);
    final date = formatDate(day);
    final previousDate = formatDate(addDays(day, -1));
    final sleptBefore = log.sleepBefore(date);
    final bedtimeBefore = log.bedtimeOf(previousDate);
    final wakeUp = log.wakeUpOn(date);
    final naps = log.napsOn(date);
    return [
      if (sleptBefore != null && bedtimeBefore != null && wakeUp != null)
        TodayFact(
          label: 'Sleep',
          value: formatDuration(sleptBefore),
          // The night as a bar, so early, late, long and short show at
          // a glance.
          visual: _SleepBar(bedtime: bedtimeBefore, wakeUp: wakeUp),
          note: naps.isEmpty ? null : 'Naps: ${formatDuration(_totalOf(naps))}',
        )
      else
        TodayFact(
          label: 'Sleep',
          value: TodayFact.unknownValue,
          // Say exactly what is missing, so it is easy to fill in.
          note: wakeUp != null
              ? 'Bedtime not logged'
              : bedtimeBefore != null
              ? 'Wake-up not logged'
              : 'Not logged yet',
        ),
      _awakeFact(
        wakeUp,
        log.bedtimeOf(date),
        now,
        isToday: day == currentDay(now),
      ),
    ];
  }

  @override
  TileDetail? weekSummary(AppState appState, DateTime day) {
    final log = SleepLog.of(appState);
    var total = Duration.zero;
    var nights = 0;
    for (var back = 0; back < 7; back++) {
      final slept = log.sleepBefore(formatDate(addDays(day, -back)));
      if (slept != null) {
        total += slept;
        nights++;
      }
    }
    if (nights == 0) {
      return null;
    }
    return TileDetail(formatDuration(total ~/ nights), label: 'Sleep');
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}

/// The "Awake for" tile: time since waking up today, or, once you went
/// to bed, how long the day lasted, with the day drawn as a bar. Looking
/// back at an earlier day, only the day's length can be shown.
TodayFact _awakeFact(
  SleepMoment? wakeUp,
  SleepMoment? bedtime,
  DateTime now, {
  required bool isToday,
}) {
  if (wakeUp == null) {
    return const TodayFact(
      label: 'Awake for',
      value: TodayFact.unknownValue,
      note: 'Not logged yet',
    );
  }
  final nowUtc = now.toUtc();
  if (bedtime != null && !nowUtc.isBefore(bedtime.atUtc)) {
    return TodayFact(
      label: 'Awake for',
      value: formatDuration(bedtime.atUtc.difference(wakeUp.atUtc)),
      visual: _DayBar(
        start: wakeUp.clock,
        end: bedtime.clock,
        endLabel: bedtime.clock.shown,
      ),
    );
  }
  if (!isToday) {
    return const TodayFact(
      label: 'Awake for',
      value: TodayFact.unknownValue,
      note: 'Bedtime not logged',
    );
  }
  final awake = nowUtc.difference(wakeUp.atUtc);
  return TodayFact(
    label: 'Awake for',
    value: awake.isNegative ? TodayFact.unknownValue : formatDuration(awake),
    visual: _DayBar(
      start: wakeUp.clock,
      end: ClockTime(now.hour, now.minute),
      endLabel: 'now',
    ),
  );
}

/// The total time of [naps].
Duration _totalOf(List<Nap> naps) {
  var total = Duration.zero;
  for (final nap in naps) {
    total += nap.duration;
  }
  return total;
}

/// The night, from bedtime to waking up, in the theme's accent colour.
class _SleepBar extends StatelessWidget {
  const _SleepBar({required this.bedtime, required this.wakeUp});

  final SleepMoment bedtime;
  final SleepMoment wakeUp;

  @override
  Widget build(BuildContext context) {
    return TimeSpanBar(
      start: bedtime.clock,
      end: wakeUp.clock,
      trackStartHour: TimeSpanBar.nightStartHour,
      trackHours: TimeSpanBar.nightHours,
      startLabel: bedtime.clock.shown,
      endLabel: wakeUp.clock.shown,
      description:
          'Bed at ${bedtime.clock.shown}, woke at ${wakeUp.clock.shown}',
    );
  }
}

/// The day, from waking up to [end] (now, or bedtime), in the theme's
/// accent colour.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.start,
    required this.end,
    required this.endLabel,
  });

  final ClockTime start;
  final ClockTime end;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    return TimeSpanBar(
      start: start,
      end: end,
      trackStartHour: TimeSpanBar.dayStartHour,
      trackHours: TimeSpanBar.dayHours,
      startLabel: start.shown,
      endLabel: endLabel,
      description: 'Awake from ${start.shown} to $endLabel',
    );
  }
}
