// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you went to bed, woke up, and napped.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'screens/sleep_screen.dart';
import 'sleep_episode.dart';
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

  /// Two tiles: last night's sleep (with any naps), and how long since
  /// waking up.
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final log = SleepLog.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(now);
    final night = log.nightOn(today);
    final naps = log.napsOn(today);
    final details = [
      if (night != null) '${night.startClock} – ${night.endClock}',
      if (naps.isNotEmpty) _describeNaps(naps),
    ];
    return [
      TodayFact(
        icon: Icons.bedtime,
        label: 'Sleep',
        value: night == null
            ? TodayFact.unknownValue
            : formatDuration(night.duration),
        detail: details.isEmpty ? 'Not logged yet' : details.join(' · '),
      ),
      _awakeFact(night, now),
    ];
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}

/// The "Awake for" tile: time since waking up from last night's sleep.
TodayFact _awakeFact(SleepEpisode? night, DateTime now) {
  final awake = night == null ? null : now.toUtc().difference(night.endedAtUtc);
  // Only while it makes sense: after waking, and within a day.
  if (night == null ||
      awake == null ||
      awake.isNegative ||
      awake >= const Duration(hours: 24)) {
    return const TodayFact(
      icon: Icons.wb_sunny_outlined,
      label: 'Awake for',
      value: TodayFact.unknownValue,
      detail: 'Not logged yet',
    );
  }
  return TodayFact(
    icon: Icons.wb_sunny_outlined,
    label: 'Awake for',
    value: formatDuration(awake),
    detail: 'since ${night.endClock}',
  );
}

/// Describes naps, for example `nap 20 min` or `2 naps 45 min`.
String _describeNaps(List<SleepEpisode> naps) {
  var total = Duration.zero;
  for (final nap in naps) {
    total += nap.duration;
  }
  final count = naps.length == 1 ? 'nap' : '${naps.length} naps';
  return '$count ${formatDuration(total)}';
}
