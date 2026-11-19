// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you woke up and went to bed each day, and
/// naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/theme.dart';
import 'screens/sleep_screen.dart';
import 'nap.dart';
import 'night_bar.dart';
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

  @override
  Color get color => const Color(0xFF6F7FD6); // lavender blue

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
          visual: _SleepBar(
            bedtime: bedtimeBefore,
            wakeUp: wakeUp,
            base: color,
          ),
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
    return TileDetail(formatDuration(total ~/ nights), label: 'Sleep / night');
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}

/// The "Awake for" tile: time since waking up today, or, once you went
/// to bed, how long the day lasted. Looking back at an earlier day, only
/// the day's length can be shown.
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
      details: [
        TileDetail(wakeUp.clock.shown, label: 'Woke'),
        TileDetail(bedtime.clock.shown, label: 'Bed'),
      ],
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
    details: [TileDetail(wakeUp.clock.shown, label: 'Woke')],
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

/// The night bar in the sleep module's colour, toned for the theme.
class _SleepBar extends StatelessWidget {
  const _SleepBar({
    required this.bedtime,
    required this.wakeUp,
    required this.base,
  });

  final SleepMoment bedtime;
  final SleepMoment wakeUp;
  final Color base;

  @override
  Widget build(BuildContext context) {
    return NightBar(
      bedtime: bedtime.clock,
      wakeUp: wakeUp.clock,
      color: moduleTone(base, Theme.of(context).brightness),
    );
  }
}
