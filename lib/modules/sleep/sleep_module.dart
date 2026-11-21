// SPDX-License-Identifier: GPL-3.0-or-later

/// The sleep module: when you woke up and went to bed each day, and
/// naps.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/widgets/moon_icon.dart';
import 'screens/sleep_screen.dart';
import 'nap.dart';
import 'time_span_bar.dart';
import 'sleep_moment.dart';
import 'sleep_log.dart';
import 'sleep_demo.dart';

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

  /// A full, even crescent with a small star, drawn by hand: Material's
  /// moons are thin or lopsided at small sizes.
  @override
  Widget buildIcon() => const MoonIcon();

  /// The sleep the night before [day], drawn as a bar from bedtime to
  /// waking up; then how long you have been awake (or naps), and the
  /// nightly average over the week before.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final log = SleepLog.of(appState);
    final date = formatDate(day);
    final sleptBefore = log.sleepBefore(date);
    final bedtimeBefore = log.bedtimeOf(formatDate(addDays(day, -1)));
    final wakeUp = log.wakeUpOn(date);
    final average = log.averageSleepBefore(day);
    final averageRow = average == null
        ? null
        : TileRow('Avg (7 nights)', formatDuration(average));
    if (sleptBefore == null || bedtimeBefore == null || wakeUp == null) {
      return HomeTile(
        value: HomeTile.unknownValue,
        // Say exactly what is missing, so it is easy to fill in.
        note: wakeUp != null
            ? 'Bedtime not logged'
            : bedtimeBefore != null
            ? 'Wake-up not logged'
            : 'Not logged yet',
        rows: [if (averageRow != null) averageRow],
      );
    }
    final dayRow = _dayRow(
      log,
      date,
      wakeUp,
      now,
      isToday: day == currentDay(now),
    );
    return HomeTile(
      value: formatDuration(sleptBefore),
      valueNote: 'slept',
      mark: _SleepBar(bedtime: bedtimeBefore, wakeUp: wakeUp),
      rows: [if (dayRow != null) dayRow, if (averageRow != null) averageRow],
    );
  }

  /// The hours slept the night before each of the seven days, to a
  /// tenth: `7.5`.
  @override
  List<WeekRow> weekRows(AppState appState, DateTime day) {
    final log = SleepLog.of(appState);
    final hours = [
      for (final column in weekEndingOn(day))
        log.sleepBefore(formatDate(column))?.inMinutes,
    ];
    if (hours.every((minutes) => minutes == null)) {
      return const [];
    }
    return [
      WeekRow(
        label: 'Sleep (h)',
        cells: [
          for (final minutes in hours)
            minutes == null ? null : (minutes / 60).toStringAsFixed(1),
        ],
        description: 'Hours slept each night',
      ),
    ];
  }

  /// Days with a wake-up, a bedtime or a nap logged.
  @override
  Set<String> datesLogged(AppState appState) {
    final log = SleepLog.of(appState);
    return {
      for (final moment in log.moments)
        if (!moment.isDeleted) moment.date,
      for (final nap in log.naps)
        if (!nap.isDeleted) nap.date,
    };
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);

  /// Hours slept each night.
  @override
  List<TrendMeasure> trendMeasures(AppState appState) {
    final log = SleepLog.of(appState);
    if (log.moments.every((moment) => moment.isDeleted)) {
      return const [];
    }
    return [
      TrendMeasure(
        label: 'Sleep',
        valueOn: (date) {
          final minutes = log.sleepBefore(date)?.inMinutes;
          return minutes?.toDouble();
        },
        // The exact average, written as the tile writes its average, so
        // the two always show the same minutes.
        format: (minutes) => formatDuration(
          Duration(
            microseconds: (minutes * Duration.microsecondsPerMinute).round(),
          ),
        ),
      ),
    ];
  }

  @override
  List<DemoEvent> demoEvents(DemoPlan plan) => sleepDemoEvents(plan);
}

/// One fact about the day after the night: how long you have been awake
/// (today, before bed), or the day's naps; null for neither.
TileRow? _dayRow(
  SleepLog log,
  String date,
  SleepMoment wakeUp,
  DateTime now, {
  required bool isToday,
}) {
  final bedtime = log.bedtimeOf(date);
  final awake = now.toUtc().difference(wakeUp.atUtc);
  if (isToday && bedtime == null && !awake.isNegative) {
    return TileRow('Awake for', formatDuration(awake));
  }
  final naps = log.napsOn(date);
  if (naps.isNotEmpty) {
    return TileRow('Naps', formatDuration(_totalOf(naps)));
  }
  return null;
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
