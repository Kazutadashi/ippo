// SPDX-License-Identifier: GPL-3.0-or-later

/// A bar for choosing which day a screen shows: ‹ Today ›.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';

/// Returns today's date at local midnight.
DateTime today() => _calendarToday();

DateTime _calendarToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Shows the chosen day with buttons for the previous and next day.
/// Tapping the day opens a calendar.
class DayBar extends StatelessWidget {
  /// Creates the bar showing [day], reporting a new day to [onChanged].
  ///
  /// [today] is the day called "Today"; it is the calendar day unless a
  /// screen counts days differently (for sleep, the day lasts until
  /// early morning).
  const DayBar({
    super.key,
    required this.day,
    required this.onChanged,
    this.today,
  });

  /// The day shown, at local midnight.
  final DateTime day;

  /// The day called "Today", or null for the calendar day.
  final DateTime? today;

  /// Called with the newly chosen day.
  final ValueChanged<DateTime> onChanged;

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: addDays(_calendarToday(), 365),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(addDays(day, -1)),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => _pickDay(context),
            child: Text(describeDay(day, today: today)),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(addDays(day, 1)),
        ),
      ],
    );
  }
}

/// Names a day: `Today`, `Yesterday`, `Tomorrow`, or for example
/// `Mon 2026-11-16`. [today] is the day called "Today", the calendar
/// day if not given.
String describeDay(DateTime day, {DateTime? today}) {
  final todayDate = today ?? _calendarToday();
  if (day == todayDate) {
    return 'Today';
  }
  if (day == addDays(todayDate, -1)) {
    return 'Yesterday';
  }
  if (day == addDays(todayDate, 1)) {
    return 'Tomorrow';
  }
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[day.weekday - 1]} ${formatDate(day)}';
}
