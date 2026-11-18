// SPDX-License-Identifier: GPL-3.0-or-later

/// A button showing a time, such as "Bed 23:30", that opens a clock to
/// change it.
library;

import 'package:material_ui/material_ui.dart';

import '../sleep_times.dart';

/// Shows [label] and [time]; tapping opens the system time picker.
class TimeButton extends StatelessWidget {
  /// Creates the button.
  const TimeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.time,
    required this.onChanged,
  });

  /// What the time is, for example `Bed`.
  final String label;

  /// An icon next to the label.
  final IconData icon;

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
    return OutlinedButton.icon(
      onPressed: () => _pick(context),
      icon: Icon(icon),
      label: Text('$label $time'),
    );
  }
}
