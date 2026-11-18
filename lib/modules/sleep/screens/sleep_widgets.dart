// SPDX-License-Identifier: GPL-3.0-or-later

/// The time field used by the sleep screens. The other building blocks
/// are shared by every screen, in `lib/core/widgets/section_card.dart`.
library;

import 'package:material_ui/material_ui.dart';

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
