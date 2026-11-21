// SPDX-License-Identifier: GPL-3.0-or-later

/// Fields for a time, or a date and time, that open the system pickers.
library;

import 'package:material_ui/material_ui.dart';

import '../clock_time.dart';
import '../dates.dart';

/// A time the user can change. It looks like a text field (outline and
/// label), and tapping it opens the system clock picker.
///
/// [time] null shows "Not set".
class TimeField extends StatelessWidget {
  /// Creates the field showing [time] with [label].
  const TimeField({
    super.key,
    required this.label,
    required this.time,
    required this.onChanged,
    this.suggestion,
  });

  /// What the time is, for example `Start`.
  final String label;

  /// The time shown, or null for "Not set".
  final ClockTime? time;

  /// Where the picker starts when [time] is null; now if not given.
  final ClockTime? suggestion;

  /// Called with the newly picked time.
  final ValueChanged<ClockTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final start = time ?? suggestion ?? ClockTime(now.hour, now.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
      helpText: label,
    );
    if (picked != null) {
      onChanged(ClockTime(picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          time == null ? 'Not set' : time.shown,
          style: time == null
              ? textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : textTheme.titleLarge,
        ),
      ),
    );
  }
}

/// A day the user can change, such as "Thu 19 Nov". It looks like a
/// text field (outline and label), and tapping it opens the calendar. No
/// day after today can be picked: nothing can be logged there yet.
class DateField extends StatelessWidget {
  /// Creates the field showing [day] with [label].
  const DateField({
    super.key,
    required this.label,
    required this.day,
    required this.onChanged,
  });

  /// What the day is, for example `Day`.
  final String label;

  /// The day shown (a date, no time).
  final DateTime day;

  /// Called with the newly picked day.
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final last = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: day.isAfter(last) ? last : day,
      firstDate: DateTime(2000),
      lastDate: last,
      helpText: label,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          _shortDay(day),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

/// [day] briefly enough for half a phone's width: `Today`, `Yesterday`,
/// or the date, such as `19 Nov`.
String _shortDay(DateTime day) {
  final daysAgo = daysBetween(day, today());
  if (daysAgo == 0) {
    return 'Today';
  }
  if (daysAgo == 1) {
    return 'Yesterday';
  }
  return '${day.day} ${shortMonthName(day.month)}';
}

/// A day and a time side by side at equal width, such as when a meal was
/// eaten: the [day] it counts for, and the [time] on the clock (null for
/// "Not set"). Changing the day moves the thing to another day.
class DayAndTimeFields extends StatelessWidget {
  /// Creates the two fields.
  const DayAndTimeFields({
    super.key,
    required this.day,
    required this.time,
    required this.onDayChanged,
    required this.onTimeChanged,
  });

  /// The day shown.
  final DateTime day;

  /// The time shown, or null for "Not set".
  final ClockTime? time;

  /// Called with a newly picked day.
  final ValueChanged<DateTime> onDayChanged;

  /// Called with a newly picked time.
  final ValueChanged<ClockTime> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DateField(label: 'Day', day: day, onChanged: onDayChanged),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TimeField(
            label: 'Eaten at',
            time: time,
            onChanged: onTimeChanged,
          ),
        ),
      ],
    );
  }
}

/// A date and time the user can change, such as "Thu 19 Nov, 01:00". It
/// looks like a text field (outline and label).
///
/// The usual change is the time, so tapping the field opens the clock
/// picker straight away, and [momentFor] works out the date (a bedtime of
/// 01:00 is on the next calendar day). The calendar button changes the
/// date itself, for the rare case where that is wrong.
///
/// [value] null shows "Not set". With [isSuggestion], the value is only
/// a suggestion that is not saved yet: it is shown in grey, marked
/// "Suggested", so it is never mistaken for a saved time.
class DateTimeField extends StatelessWidget {
  /// Creates the field.
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.suggestion,
    required this.momentFor,
    required this.onChanged,
    this.isSuggestion = false,
  });

  /// What the moment is, for example `Went to bed`.
  final String label;

  /// The chosen moment, or null if none yet.
  final DateTime? value;

  /// Where the pickers start when [value] is null.
  final DateTime suggestion;

  /// Turns a picked clock time into a moment, choosing its date.
  final DateTime Function(ClockTime time) momentFor;

  /// Whether [value] is a suggestion that has not been saved.
  final bool isSuggestion;

  /// Called with the newly picked moment.
  final ValueChanged<DateTime> onChanged;

  Future<void> _pickTime(BuildContext context) async {
    final start = value ?? suggestion;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
      helpText: label,
    );
    if (picked != null) {
      onChanged(momentFor(ClockTime(picked.hour, picked.minute)));
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final start = value ?? suggestion;
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(2000),
      lastDate: DateTime(start.year + 1),
      helpText: label,
    );
    if (picked != null) {
      onChanged(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          start.hour,
          start.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final greyed = value == null || isSuggestion;
    return InkWell(
      onTap: () => _pickTime(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: isSuggestion ? 'Suggested' : null,
          suffixIcon: IconButton(
            tooltip: 'Change date',
            icon: const Icon(Icons.event),
            onPressed: () => _pickDate(context),
          ),
        ),
        // Two lines either way, so a field that is not set is as tall as
        // one that is, and side-by-side fields line up.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value == null ? ' ' : formatShortDate(value),
              style: textTheme.bodyMedium?.copyWith(
                color: greyed ? muted : null,
              ),
            ),
            // "Not set" smaller than a time, so it does not read as one,
            // but on a line of the same height.
            Text(
              value == null ? 'Not set' : showTimeOfDay(value),
              style: value == null
                  ? textTheme.bodyLarge?.copyWith(color: muted)
                  : textTheme.titleLarge?.copyWith(
                      color: greyed ? muted : null,
                    ),
              strutStyle: StrutStyle.fromTextStyle(
                textTheme.titleLarge!,
                forceStrutHeight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
