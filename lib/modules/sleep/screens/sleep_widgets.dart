// SPDX-License-Identifier: GPL-3.0-or-later

/// The time and date-time fields used by the sleep screens. The other
/// building blocks are shared by every screen, in
/// `lib/core/widgets/section_card.dart`.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../sleep_times.dart';

/// A time the user can change. It looks like a text field (outline and
/// label), and tapping it opens the system clock picker.
class TimeField extends StatelessWidget {
  /// Creates the field showing [time] with [label].
  const TimeField({
    super.key,
    required this.label,
    required this.time,
    required this.onChanged,
  });

  /// What the time is, for example `Went to bed`.
  final String label;

  /// The time shown.
  final ClockTime time;

  /// Called with the newly picked time.
  final ValueChanged<ClockTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: label,
    );
    if (picked != null) {
      onChanged(ClockTime(picked.hour, picked.minute));
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
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.schedule),
        ),
        child: Text('$time', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

/// A date and time the user can change, such as "Thu 19 Nov, 01:00". It
/// looks like a text field (outline and label). Tapping it opens a date
/// picker and then a time picker.
///
/// [value] null shows "Not set".
class DateTimeField extends StatelessWidget {
  /// Creates the field.
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.suggestion,
    required this.onChanged,
  });

  /// What the moment is, for example `Went to bed`.
  final String label;

  /// The chosen moment, or null if none yet.
  final DateTime? value;

  /// Where the pickers start when [value] is null.
  final DateTime suggestion;

  /// Called with the newly picked moment.
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final start = value ?? suggestion;
    final pickedDay = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(2000),
      lastDate: DateTime(start.year + 1),
      helpText: label,
    );
    if (pickedDay == null || !context.mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
      helpText: label,
    );
    if (pickedTime == null) {
      return;
    }
    onChanged(
      DateTime(
        pickedDay.year,
        pickedDay.month,
        pickedDay.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.event),
        ),
        // Two lines either way, so a field that is not set is as tall as
        // one that is, and side-by-side fields line up.
        child: value == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(' ', style: textTheme.bodyMedium),
                  Text(
                    'Not set',
                    style: textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatShortDate(value), style: textTheme.bodyMedium),
                  Text(formatTimeOfDay(value), style: textTheme.titleLarge),
                ],
              ),
      ),
    );
  }
}
