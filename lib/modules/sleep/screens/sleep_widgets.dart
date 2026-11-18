// SPDX-License-Identifier: GPL-3.0-or-later

/// Small building blocks shared by the sleep screens.
///
/// They follow one rule so the screen is easy to read: anything that can
/// be changed looks like a form field, information is plain text, and
/// actions are buttons.
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

/// A piece of information: a small label above a larger value, such as
/// "Woke up" above "07:00". Plain text, so it never looks tappable.
class InfoValue extends StatelessWidget {
  /// Creates the information block.
  const InfoValue({super.key, required this.label, required this.value});

  /// What the value is.
  final String label;

  /// The value itself.
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        // Shrink a long value (such as "10 h 45 min") instead of wrapping.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: textTheme.titleLarge),
        ),
      ],
    );
  }
}

/// A card heading: an icon and a title on the left, and an optional
/// action (such as an "Add" button) on the right.
class CardHeader extends StatelessWidget {
  /// Creates the heading.
  const CardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action,
  });

  /// The icon before the title.
  final IconData icon;

  /// The title.
  final String title;

  /// A button shown on the right, if any.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return SizedBox(
      // The same height with or without a button, so cards line up.
      height: 40,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

/// Plain, muted text for short notes such as "No naps on this day."
class NoteText extends StatelessWidget {
  /// Creates the note.
  const NoteText(this.text, {super.key});

  /// The note.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// Red text for a problem the user has to fix.
class ProblemText extends StatelessWidget {
  /// Creates the problem text.
  const ProblemText(this.text, {super.key});

  /// What is wrong.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
