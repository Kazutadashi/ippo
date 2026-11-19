// SPDX-License-Identifier: GPL-3.0-or-later

/// A night's sleep drawn as a bar, for the home screen.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/clock_time.dart';

/// The hour the bar starts at, in the evening. The bar runs from here to
/// [_endHour] the next day, which covers almost every night.
const int _startHour = 20;

/// The hour the bar ends at, the next day.
const int _endHour = 12;

/// A night from [bedtime] to [wakeUp] as a filled stretch of a bar that
/// runs from 20:00 to noon, with the two times below its ends. A mark,
/// not a chart: it shows at a glance whether the night was early or
/// late, long or short.
class NightBar extends StatelessWidget {
  /// Creates the bar.
  const NightBar({
    super.key,
    required this.bedtime,
    required this.wakeUp,
    required this.color,
  });

  /// When you went to bed.
  final ClockTime bedtime;

  /// When you woke up.
  final ClockTime wakeUp;

  /// The sleep module's colour, toned for the theme.
  final Color color;

  /// Where [time] falls on the bar, from 0 (20:00) to 1 (12:00 the next
  /// day). Times outside the bar are kept at its ends.
  static double _position(ClockTime time) {
    const length = 24 - _startHour + _endHour;
    var hours = time.hour + time.minute / 60 - _startHour;
    if (hours < -_startHour + _endHour) {
      // Early morning: after midnight, the next day.
      hours += 24;
    }
    return (hours / length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _position(bedtime);
    final end = _position(wakeUp);
    return Semantics(
      label: 'Bed at ${bedtime.shown}, woke at ${wakeUp.shown}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: width * start),
                    width: width * (end - start).clamp(0.02, 1.0),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(bedtime.shown, style: theme.textTheme.labelSmall),
                Text(wakeUp.shown, style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
