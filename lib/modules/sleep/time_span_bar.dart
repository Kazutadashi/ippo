// SPDX-License-Identifier: GPL-3.0-or-later

/// A stretch of the clock drawn as a bar, for the home screen: a night's
/// sleep, or the day since waking up.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/clock_time.dart';

/// A stretch from [start] to [end] as the filled part of a bar that
/// covers [trackHours] hours from [trackStartHour], with a label under
/// each end. A mark, not a chart: it shows at a glance whether the
/// stretch was early or late, long or short.
class TimeSpanBar extends StatelessWidget {
  /// Creates the bar.
  const TimeSpanBar({
    super.key,
    required this.start,
    required this.end,
    required this.trackStartHour,
    required this.trackHours,
    required this.startLabel,
    required this.endLabel,
    required this.color,
    required this.description,
  });

  /// The night that sleep usually falls in: 20:00 to noon.
  static const int nightStartHour = 20;

  /// How long that night bar is, in hours.
  static const int nightHours = 16;

  /// The day that waking hours usually fall in: 05:00 to 01:00.
  static const int dayStartHour = 5;

  /// How long that day bar is, in hours.
  static const int dayHours = 20;

  /// Where the filled part begins.
  final ClockTime start;

  /// Where it ends.
  final ClockTime end;

  /// The hour the bar starts at.
  final int trackStartHour;

  /// How many hours the bar covers; it may run past midnight.
  final int trackHours;

  /// The text under the start, such as `11:20 pm`.
  final String startLabel;

  /// The text under the end, such as `7:00 am` or `now`.
  final String endLabel;

  /// The module's colour, toned for the theme.
  final Color color;

  /// What a screen reader says, such as "Bed at 11:20 pm, woke at
  /// 7:00 am".
  final String description;

  /// Where [time] falls on the bar, from 0 to 1. Times before the bar's
  /// start count as the next day; times outside it stay at its ends.
  double _position(ClockTime time) {
    var hours = time.hour + time.minute / 60 - trackStartHour;
    if (hours < 0) {
      hours += 24;
    }
    return (hours / trackHours).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final from = _position(start);
    final to = _position(end);
    return Semantics(
      label: description,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: width * from),
                    width: width * (to - from).clamp(0.03, 1.0),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startLabel, style: style),
                Text(endLabel, style: style),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
