// SPDX-License-Identifier: GPL-3.0-or-later

/// A stretch of the clock drawn as a bar, for the home screen: a night's
/// sleep, or the day since waking up.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/clock_time.dart';
import '../../core/dates.dart';

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

  /// The night that sleep usually falls in: 18:00 to noon the next
  /// day, so the scale under the bar reads every 6 hours: 6 pm, 12 am,
  /// 6 am, 12 pm.
  static const int nightStartHour = 18;

  /// How long that night bar is, in hours.
  static const int nightHours = 18;

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
            // The times, above the two ends of the filled part.
            _labels(style),
            const SizedBox(height: 3),
            // The bar as three parts side by side, sized in proportion:
            // before the stretch, the stretch, and after it. (Flex parts
            // rather than measured widths, so the tile's height can be
            // worked out before it is laid out.)
            // Midnight, where one day ends and the next begins, is a thin
            // line across the bar.
            SizedBox(
              height: 12,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: _stretch(color),
                  ),
                  if (_midnight != null)
                    Align(
                      alignment: Alignment(-1 + 2 * _midnight!, 0),
                      child: Container(
                        width: 1.5,
                        height: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // The scale under the bar, quiet like an axis: every 6 hours,
            // so it is clear the bar is one night, not a whole day.
            _scale(
              style?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: (style.fontSize ?? 11) - 1,
              ),
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
  /// The bar's parts, in thousandths of its width: before the stretch,
  /// the stretch (never thinner than a sliver, so it always shows), and
  /// after it.
  (int, int, int) _parts() {
    final start = _position(this.start);
    final end = _position(this.end);
    final before = (start * 1000).round();
    final filled = max(30, ((end - start) * 1000).round());
    final after = max(0, 1000 - before - filled);
    return (before, filled, after);
  }

  /// The two times over the two ends of the stretch, not over the ends
  /// of the bar: the bar is a whole night, and the times belong to the
  /// sleep in it. The space around them is shared out as
  /// the bar is, so they sit close to the stretch's ends, and never run
  /// off the edge.
  Widget _labels(TextStyle? style) {
    final (before, filled, after) = _parts();
    return Row(
      children: [
        if (before > 0) Spacer(flex: before),
        Text(startLabel, style: style),
        Spacer(flex: filled),
        Text(endLabel, style: style),
        if (after > 0) Spacer(flex: after),
      ],
    );
  }

  /// Where midnight is along the bar, from 0 to 1, or null if the bar
  /// does not cross it.
  double? get _midnight {
    final hoursToMidnight = (24 - trackStartHour) % 24;
    if (hoursToMidnight == 0 || hoursToMidnight >= trackHours) {
      return null;
    }
    return hoursToMidnight / trackHours;
  }

  /// The hours under the bar, every 6 hours from its start to its end
  /// (`6 pm · 12 am · 6 am · 12 pm`), each placed where it is along the
  /// bar.
  Widget _scale(TextStyle? style) {
    return Stack(
      children: [
        // Keeps the row one line tall.
        Text('', style: style),
        for (var offset = 0; offset <= trackHours; offset += 6)
          Align(
            alignment: Alignment(-1 + 2 * offset / trackHours, 0),
            child: Text(
              hourLabel((trackStartHour + offset) % 24),
              style: style,
            ),
          ),
      ],
    );
  }

  Widget _stretch(Color color) {
    final (before, filled, after) = _parts();
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

/// An hour on the clock, short, as a scale shows it: `6 pm`, `12 am`,
/// `12 pm`; or `18:00` with the 24-hour clock. The same form for every
/// hour, so the scale reads evenly.
String hourLabel(int hour) {
  if (showTimesIn24Hours) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }
  final onTwelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$onTwelve ${hour < 12 ? 'am' : 'pm'}';
}
