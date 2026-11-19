// SPDX-License-Identifier: GPL-3.0-or-later

/// A stretch of the clock drawn as a bar, for the home screen: a night's
/// sleep, or the day since waking up.
library;

import 'dart:math';

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
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: description,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The bar as three parts side by side, sized in proportion:
            // before the stretch, the stretch, and after it. (Flex parts
            // rather than measured widths, so the tile's height can be
            // worked out before it is laid out.)
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: _stretch(start, end, color),
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

  /// The bar's stretch from [from] to [to] in [color], as three parts
  /// side by side, sized in proportion: before the stretch, the stretch,
  /// and after it. (Flex parts rather than measured widths, so the
  /// tile's height can be worked out before it is laid out.)
  Widget _stretch(ClockTime from, ClockTime to, Color color) {
    final start = _position(from);
    final end = _position(to);
    // In thousandths of the bar; the stretch is never thinner than a
    // sliver, so it always shows.
    final before = (start * 1000).round();
    final filled = max(30, ((end - start) * 1000).round());
    final after = max(0, 1000 - before - filled);
    return Row(
      // The filled part takes the bar's full height.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (before > 0) Spacer(flex: before),
        Expanded(
          flex: filled,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (after > 0) Spacer(flex: after),
      ],
    );
  }
}
