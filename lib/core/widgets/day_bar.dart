// SPDX-License-Identifier: GPL-3.0-or-later

/// A bar for choosing which day a screen shows: ‹ 📅 Today ›, and on
/// another day a "Today" button to go straight back.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';

/// Shows the chosen day with buttons for the previous and next day.
/// Tapping the day opens a calendar. It goes in a screen's top bar
/// (`AppBar.actions`), next to the title.
///
/// On any day but today, the day is shown in a tinted pill (logging to
/// the wrong day by mistake is easy to miss otherwise), and a "Today"
/// button snaps back.
class DayBar extends StatelessWidget {
  /// Creates the bar showing [day], reporting a new day to [onChanged].
  const DayBar({super.key, required this.day, required this.onChanged});

  /// The day shown, at local midnight.
  final DateTime day;

  /// Called with the newly chosen day.
  final ValueChanged<DateTime> onChanged;

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: addDays(today(), 365),
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
        // logging to the wrong day is easy to miss otherwise.
        TextButton.icon(
          onPressed: () => _pickDay(context),
          style: TextButton.styleFrom(
            backgroundColor: isToday ? null : colors.secondaryContainer,
            foregroundColor: isToday ? foreground : colors.onSecondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(describeDay(day)),
        ),
        IconButton(
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(addDays(day, 1)),
        ),
        // On another day, one tap goes back to today.
        if (!isToday)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: foreground,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 40),
            ),
            onPressed: () => onChanged(today()),
            child: const Text('Today'),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Names a day: `Today`, `Yesterday`, `Tomorrow`, or for example
/// `Mon 16 Nov`. Today is the day you are in (see [currentDay]).
String describeDay(DateTime day) {
  final todayDate = today();
  if (day == todayDate) {
    return 'Today';
  }
  if (day == addDays(todayDate, -1)) {
    return 'Yesterday';
  }
  if (day == addDays(todayDate, 1)) {
    return 'Tomorrow';
  }
  return formatShortDate(day);
}
