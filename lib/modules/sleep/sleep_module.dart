// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you woke up and went to bed each day, and
/// naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'screens/sleep_screen.dart';
import 'nap.dart';
import 'sleep_moment.dart';
import 'sleep_log.dart';

/// The sleep module, as seen by the core app.
class SleepModule implements IppoModule {
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
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final log = SleepLog.of(appState);
    final day = currentDay(now);
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
          details: [
            TileDetail(bedtimeBefore.clock.shown, label: 'Bed'),
            TileDetail(wakeUp.clock.shown, label: 'Woke'),
            if (naps.isNotEmpty)
              TileDetail(formatDuration(_totalOf(naps)), label: 'Naps'),
          ],
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
      _awakeFact(wakeUp, log.bedtimeOf(date), now),
    ];
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}

/// The "Awake for" tile: time since waking up today, or, once you went
/// to bed, how long the day lasted.
TodayFact _awakeFact(SleepMoment? wakeUp, SleepMoment? bedtime, DateTime now) {
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
