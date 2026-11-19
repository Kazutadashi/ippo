// SPDX-License-Identifier: GPL-3.0-or-later

/// A bar for choosing which day a screen shows: ‹ Today ▾ ›.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';

/// Shows the chosen day with buttons for the previous and next day.
/// Tapping the day opens a calendar. It goes in a screen's top bar
/// (`AppBar.actions`), next to the title.
///
/// On any day but today, the day is shown in a tinted pill: logging to
/// the wrong day by mistake is easy to miss otherwise.
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
    // Compact, so it fits in a screen's top bar next to the title.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(addDays(day, -1)),
        ),
        // A minimum width, so the arrows stay in place as the label
        // changes from "Today" to "Mon 16 Nov".
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 116),
          child: TextButton.icon(
            onPressed: () => _pickDay(context),
            style: TextButton.styleFrom(
              backgroundColor: isToday ? null : colors.secondaryContainer,
              foregroundColor: colors.onSurface,
            ),
            // The arrow says the day opens a calendar.
            icon: const Icon(Icons.arrow_drop_down),
            iconAlignment: IconAlignment.end,
            label: Text(describeDay(day)),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(addDays(day, 1)),
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
