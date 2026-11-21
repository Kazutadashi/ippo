// SPDX-License-Identifier: GPL-3.0-or-later

/// The Sleep tab's charts: how long each night was, and when it was.
library;

import '../../core/app_state.dart';
import '../../core/dates.dart';
import '../../core/module.dart';
import 'sleep_log.dart';
import 'sleep_moment.dart';

/// Hours slept, and bedtime to waking up, each night that both were
/// logged. Empty before the first such night.
List<ChartSpec> sleepCharts(AppState appState) {
  final log = SleepLog.of(appState);
  final wakeDates = {
    for (final moment in log.moments)
      if (!moment.isDeleted && moment.kind == MomentKind.wokeUp) moment.date,
  };
  final hours = dailyValues(wakeDates, (date) {
    final slept = log.sleepBefore(date);
    return slept == null ? null : slept.inMinutes / 60;
  });
  if (hours.isEmpty) {
    return const [];
  }
  return [_durationChart(hours), _timingChart(log, wakeDates)];
}

/// Hours slept, with the band advised for adults.
ChartSpec _durationChart(List<DayValue> hours) {
  return ChartSpec(
    title: 'Sleep',
    unit: 'h',
    values: hours,
    format: _formatHours,
    valueLabel: 'Each night',
    countLabel: 'Nights',
    reference: const ReferenceBand(low: 7, high: 9, label: '7–9 h advised'),
    note:
        'The band is the 7 to 9 hours advised for adults by the US '
        'National Sleep Foundation (Hirshkowitz et al., Sleep Health, '
        '2015).',
  );
}

/// When each night was: a bar from bedtime to waking up, on the day of
/// waking up, against the clock. The summary is about mid-sleep, the
/// halfway point of the night, which sleep research uses to compare
/// sleep timing (it moves when either end moves).
ChartSpec _timingChart(SleepLog log, Set<String> wakeDates) {
  final nights = <DayRange>[];
  for (final date in wakeDates) {
    final night = _nightBefore(log, date);
    if (night != null) {
      nights.add(night);
    }
  }
  return ChartSpec(
    title: 'Sleep times',
    values: [
      for (final night in nights)
        DayValue(night.date, (night.low + night.high) / 2),
    ],
    format: _formatClockHours,
    formatChange: _formatHours,
    formatTick: _formatClockTick,
    mark: ChartMark.none,
    valueLabel: 'Mid-sleep',
    countLabel: 'Nights',
    ranges: nights,
    rangeLabel: 'Bed to wake-up',
    tickSteps: const [1, 2, 3, 6],
  );
}

/// The night before [date] as a span of hours from the midnight that
/// starts [date]: going to bed at 23:30 is −0.5, waking at 07:00 is 7.
/// Null unless both ends are logged. The clock times are those where the
/// user was, so a night away from home reads as it was lived.
DayRange? _nightBefore(SleepLog log, String date) {
  final day = parseDate(date);
  final wakeUp = log.wakeUpOn(date);
  if (day == null || wakeUp == null || log.sleepBefore(date) == null) {
    return null;
  }
  final bedtime = log.bedtimeOf(formatDate(addDays(day, -1)));
  if (bedtime == null || wakeUp.isAfterMidnight) {
    return null;
  }
  final wokeAt = _clockHours(wakeUp);
  // A bedtime before midnight was on the day before: count back from
  // midnight.
  final wentAt = _clockHours(bedtime) - (bedtime.isAfterMidnight ? 0 : 24);
  if (wentAt >= wokeAt) {
    return null;
  }
  return DayRange(day, wentAt, wokeAt);
}

/// The clock time of [moment] in hours, such as 7.5 for 07:30.
double _clockHours(SleepMoment moment) =>
    moment.clock.hour + moment.clock.minute / 60;

/// Hours as `7 h 30 min`.
String _formatHours(double hours) =>
    formatDuration(Duration(minutes: (hours * 60).round()));

/// Hours from midnight as a clock time, such as `23:30` for −0.5.
String _formatClockHours(double hours) {
  final minutes = (hours * 60).round() % (24 * 60);
  return formatClock(minutes ~/ 60, minutes % 60);
}

/// An axis label: `22:00`, or `10 pm` with the 12-hour clock, which
/// would be too wide written out in full.
String _formatClockTick(double hours) {
  final hour = hours.round() % 24;
  if (showTimesIn24Hours) {
    return formatClock(hour, 0);
  }
  final hourOn12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hourOn12 ${hour < 12 ? 'am' : 'pm'}';
}
