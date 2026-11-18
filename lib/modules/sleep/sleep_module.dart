// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you went to bed, woke up, and napped.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'screens/sleep_screen.dart';
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

  /// For example: Slept 7 h 30 min · Woke up 07:00 · Awake for 6 h.
  /// If there were naps, they replace "Woke up".
  @override
  List<TodayFact> todayFacts(AppState appState, DateTime now) {
    final log = SleepLog.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(now);
    final night = log.nightOn(today);
    final naps = log.napsOn(today);
    final facts = <TodayFact>[];
    if (night != null) {
      facts.add(TodayFact('Slept', formatDuration(night.duration)));
    }
    if (naps.isNotEmpty) {
      var napTime = Duration.zero;
      for (final nap in naps) {
        napTime += nap.duration;
      }
      final label = naps.length == 1 ? 'Nap' : '${naps.length} naps';
      facts.add(TodayFact(label, formatDuration(napTime)));
    } else if (night != null) {
      facts.add(TodayFact('Woke up', '${night.endClock}'));
    }
    if (night != null) {
      final awake = now.toUtc().difference(night.endedAtUtc);
      // Only while it makes sense: after waking, and the same day.
      if (!awake.isNegative && awake < const Duration(hours: 24)) {
        facts.add(TodayFact('Awake for', formatDuration(awake)));
      }
    }
    return facts;
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}
