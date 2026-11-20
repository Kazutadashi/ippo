// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up nights and naps for the demo (see `demo_plan.dart`).
library;

import '../../core/dates.dart';
import '../../core/events/timestamp.dart';
import '../../core/module.dart';
import 'sleep_log.dart';

/// Getting up around 07:00 and to bed around 23:15, a little later at
/// weekends and later this week, with a nap on Saturday afternoons.
List<DemoEvent> sleepDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  for (final day in plan.days) {
    final date = formatDate(day);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final woke = plan.at(day, (isWeekend ? 8 : 6.9) + plan.wobble(0.4));
    events.add(
      plan.event(
        woke.add(const Duration(minutes: 4)),
        sleepModuleName,
        'woke_up_recorded',
        {'date': date, 'at': formatTimestamp(woke)},
      ),
    );
    // Hours past 24 are after midnight; the night still belongs to
    // [day]. Tonight's bedtime is left out by the plan until it happens.
    // This week, bedtimes slip about 40 minutes later, so Lately shows
    // less sleep than usual.
    final later = plan.daysAgo(day) < 7 ? 0.7 : 0.0;
    final bedtime = plan.at(
      day,
      (isWeekend ? 23.8 : 23.2) + later + plan.wobble(0.5),
    );
    events.add(
      plan.event(
        bedtime.add(const Duration(minutes: 1)),
        sleepModuleName,
        'went_to_bed_recorded',
        {'date': date, 'at': formatTimestamp(bedtime)},
      ),
    );
    if (day.weekday == DateTime.saturday) {
      final start = plan.at(day, 14.5);
      final end = start.add(Duration(minutes: 20 + plan.random.nextInt(25)));
      events.add(
        plan.event(
          end.add(const Duration(minutes: 2)),
          sleepModuleName,
          'nap_recorded',
          {
            'date': date,
            'started_at': formatTimestamp(start),
            'ended_at': formatTimestamp(end),
          },
        ),
      );
    }
  }
  return events;
}
