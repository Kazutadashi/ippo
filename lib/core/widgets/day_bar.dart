// SPDX-License-Identifier: GPL-3.0-or-later

/// A bar for choosing which day a screen shows: ‹ 📅 Today › », where
/// » goes straight back to today.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';

/// How wide the day is in the bar, whatever its name: wide enough for
/// "Wed 18 Nov" with its calendar icon (a longer name shrinks to fit).
const double _dayWidth = 124;

/// Shows the chosen day with buttons for the previous and next day.
/// Tapping the day opens a calendar. It goes in a screen's top bar
/// (`AppBar.actions`), next to the title.
///
/// On any day but today, the day is shown in a tinted pill (logging to
/// the wrong day by mistake is easy to miss otherwise), and » snaps
/// back to today. Every part keeps its place whatever the day.
class DayBar extends StatelessWidget {
  /// Creates the bar showing [day], reporting a new day to [onChanged].
  const DayBar({
    super.key,
    required this.day,
    required this.onChanged,
    this.todayBackground,
  });

  /// The day shown, at local midnight.
  final DateTime day;

  /// Called with the newly chosen day.
  final ValueChanged<DateTime> onChanged;

  /// A backing for the day when it is today, or null for none: on a busy
  /// picture (Home's landscape), a faint dark one keeps the white text
  /// readable (4.5:1).
  final Color? todayBackground;

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      // Only days that have been: there is no data ahead.
      lastDate: today(),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isToday = day == today();
    // The colour of the bar it sits in: white on a sky band, the text
    // colour on a plain page.
    final foreground = IconTheme.of(context).color ?? colors.onSurface;
    // Compact, so it fits in a screen's top bar next to the title.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(addDays(day, -1)),
        ),
        // The day, with a calendar icon that says tapping it opens a
        // calendar. Another day than today is in a tinted pill, as
        // logging to the wrong day is easy to miss otherwise. Always the
        // same width, so the arrows never move as the day changes.
        SizedBox(
          width: _dayWidth,
          child: TextButton.icon(
            onPressed: () => _pickDay(context),
            style: TextButton.styleFrom(
              backgroundColor: isToday
                  ? todayBackground
                  : colors.secondaryContainer,
              foregroundColor: isToday
                  ? foreground
                  : colors.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(describeDay(day)),
            ),
          ),
        ),
        // Greyed out on today: there is nothing ahead to show.
        IconButton(
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday ? null : () => onChanged(addDays(day, 1)),
        ),
        // Straight to today, always in its place at the end, as in
        // calendar apps: greyed out on today, so nothing appears or moves.
        IconButton(
          tooltip: 'Go to today',
          icon: const Icon(Icons.keyboard_double_arrow_right),
          onPressed: isToday ? null : () => onChanged(today()),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Names a day: `Today`, `Yesterday`, or for example
/// `Mon 16 Nov`. Today is the day you are in (see [currentDay]).
String describeDay(DateTime day) {
  final todayDate = today();
  if (day == todayDate) {
    return 'Today';
  }
  if (day == addDays(todayDate, -1)) {
    return 'Yesterday';
  }
  return formatShortDate(day);
}
