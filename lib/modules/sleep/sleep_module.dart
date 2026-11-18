// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you went to bed, woke up, and napped.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'screens/sleep_screen.dart';
import 'sleep_log.dart';
import 'sleep_times.dart';

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

  /// For example `Slept 7 h 30 min · 1 nap`.
  @override
  String summarizeToday(AppState appState) {
    final log = SleepLog.fromEvents(appState.eventLog?.events ?? []);
    final today = formatDate(DateTime.now());
    final night = log.nightOn(today);
    final napCount = log.napsOn(today).length;
    final parts = [
      if (night != null) 'Slept ${formatDuration(night.duration)}',
      if (napCount == 1) '1 nap',
      if (napCount > 1) '$napCount naps',
    ];
    return parts.isEmpty ? 'Nothing logged today' : parts.join(' · ');
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}
