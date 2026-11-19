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
  IconData get icon => Icons.king_bed_outlined;

  /// The sleep the night before [day], drawn as a bar over the usual
  /// night; then how long you have been awake (or naps), and the 7-day
  /// average.
  @override
  HomeTile homeTile(AppState appState, DateTime day, DateTime now) {
    final log = SleepLog.of(appState);
    final date = formatDate(day);
    final sleptBefore = log.sleepBefore(date);
    final bedtimeBefore = log.bedtimeOf(formatDate(addDays(day, -1)));
    final wakeUp = log.wakeUpOn(date);
    final average = _averageSleep(log, day);
    final averageLine = average == null
        ? null
        : '7-day avg ${formatDuration(average)}';
    if (sleptBefore == null || bedtimeBefore == null || wakeUp == null) {
      return HomeTile(
        value: HomeTile.unknownValue,
        lines: [
          // Say exactly what is missing, so it is easy to fill in.
          wakeUp != null
              ? 'Bedtime not logged'
              : bedtimeBefore != null
              ? 'Wake-up not logged'
              : 'Not logged yet',
          if (averageLine != null) averageLine,
        ],
      );
    }
    final usual = _usualNight(log, day);
    final dayLine = _dayLine(
      log,
      date,
      wakeUp,
      now,
      isToday: day == currentDay(now),
    );
    return HomeTile(
      value: formatDuration(sleptBefore),
      valueNote: 'slept',
      mark: _SleepBar(
        bedtime: bedtimeBefore,
        wakeUp: wakeUp,
        usualBedtime: usual?.bedtime,
        usualWakeUp: usual?.wakeUp,
      ),
      lines: [
        if (dayLine != null) dayLine,
        if (averageLine != null) averageLine,
      ],
    );
  }

  /// A bar for each of the seven nights, as tall as the sleep (a full
  /// bar is ten hours).
  @override
  WeekRow? weekRow(AppState appState, DateTime day) {
    final log = SleepLog.of(appState);
    final hours = [
      for (final column in weekEndingOn(day))
        log.sleepBefore(formatDate(column))?.inMinutes,
    ];
    if (hours.every((minutes) => minutes == null)) {
      return null;
    }
    final average = _averageSleep(log, addDays(day, 1));
    return WeekRow(
      values: [
        for (final minutes in hours)
          minutes == null ? null : (minutes / 60 / 10).clamp(0.0, 1.0),
      ],
      shape: WeekMarkShape.bar,
      description: average == null
          ? 'Sleep each night'
          : 'Sleep each night, ${formatDuration(average)} on average',
    );
  }

  @override
  Widget buildScreen(AppState appState) => SleepScreen(appState: appState);
}

/// The average sleep a night over the week before [day], counting only
/// nights logged; null without any.
Duration? _averageSleep(SleepLog log, DateTime day) {
  var total = Duration.zero;
  var nights = 0;
  for (final before in daysBefore(day)) {
    final slept = log.sleepBefore(formatDate(before));
    if (slept != null) {
      total += slept;
      nights++;
    }
  }
  return nights == 0 ? null : total ~/ nights;
}

/// The usual night over the week before [day]: the average bedtime and
/// wake-up, or null without a whole night logged.
({ClockTime bedtime, ClockTime wakeUp})? _usualNight(
  SleepLog log,
  DateTime day,
) {
  // Minutes after 20:00, so a bedtime after midnight averages with one
  // before it (23:30 and 00:30 make midnight, not noon).
  int afterEvening(ClockTime time) =>
      (time.minutesSinceMidnight - 20 * 60) % (24 * 60);
  ClockTime fromEvening(int minutes) {
    final clock = (minutes + 20 * 60) % (24 * 60);
    return ClockTime(clock ~/ 60, clock % 60);
  }

  var bedtimes = 0;
  var wakeUps = 0;
  var nights = 0;
  for (final before in daysBefore(day)) {
    final bedtime = log.bedtimeOf(formatDate(addDays(before, -1)));
    final wakeUp = log.wakeUpOn(formatDate(before));
    if (bedtime != null && wakeUp != null) {
      bedtimes += afterEvening(bedtime.clock);
      wakeUps += afterEvening(wakeUp.clock);
      nights++;
    }
  }
  if (nights == 0) {
    return null;
  }
  return (
    bedtime: fromEvening(bedtimes ~/ nights),
    wakeUp: fromEvening(wakeUps ~/ nights),
  );
}

/// One fact about the day after the night: how long you have been awake
/// (today, before bed), or the day's naps; null for neither.
String? _dayLine(
  SleepLog log,
  String date,
  SleepMoment wakeUp,
  DateTime now, {
  required bool isToday,
}) {
  final bedtime = log.bedtimeOf(date);
  final awake = now.toUtc().difference(wakeUp.atUtc);
  if (isToday && bedtime == null && !awake.isNegative) {
    return 'Awake ${formatDuration(awake)}';
  }
  final naps = log.napsOn(date);
  if (naps.isNotEmpty) {
    return 'Naps ${formatDuration(_totalOf(naps))}';
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
  const _SleepBar({
    required this.bedtime,
    required this.wakeUp,
    required this.usualBedtime,
    required this.usualWakeUp,
  });

  final SleepMoment bedtime;
  final SleepMoment wakeUp;

  /// The week's average night, drawn faintly behind; null for none.
  final ClockTime? usualBedtime;
  final ClockTime? usualWakeUp;

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
      usualStart: usualBedtime,
      usualEnd: usualWakeUp,
    );
  }
}
