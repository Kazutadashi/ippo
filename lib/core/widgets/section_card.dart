// SPDX-License-Identifier: GPL-3.0-or-later

/// The building blocks every screen is made of, so all screens look the
/// same.
///
/// The rules they follow:
/// - Anything that can be changed looks like a form field (the theme
///   gives every text field an outline and a label).
/// - Information is plain text: [InfoValue] and [NoteText].
/// - Each section is a [SectionCard] that starts with a [CardHeader]:
///   icon and title on the left, the card's action button on the right.
/// - A screen's main action is a full-width filled button; "Delete" is a
///   red text button below it.
library;

import 'package:material_ui/material_ui.dart';

/// A card holding one section of a screen, with the same margins and
/// padding everywhere. Its children fill the card's width.
class SectionCard extends StatelessWidget {
  /// Creates a card with [children], usually starting with a
  /// [CardHeader]. If [onTap] is given, the whole card can be tapped.
  const SectionCard({super.key, required this.children, this.onTap});

  /// What the card holds, top to bottom.
  final List<Widget> children;

  /// What tapping the card does, if anything.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      // Keeps the tap ripple inside the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A card's heading: an icon and a title on the left, and an optional
/// action (such as an "Add" or "Edit" button) on the right.
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
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

/// The standard "Add" button for a card header.
class HeaderAddButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] when tapped.
  const HeaderAddButton({super.key, required this.onPressed});

  /// What to do when tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }
}

/// The standard "Open" button for a card header, leading to another
/// screen.
class HeaderOpenButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] when tapped.
  const HeaderOpenButton({super.key, required this.onPressed});

  /// What to do when tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_right),
      iconAlignment: IconAlignment.end,
      label: const Text('Open'),
    );
  }
}

/// The standard "Edit" button for a card header.
class HeaderEditButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] when tapped.
  const HeaderEditButton({super.key, required this.onPressed});

  /// What to do when tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit'),
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

/// A row of [InfoValue]s with a small gap between them.
///
/// They share the width equally, unless [flexes] gives each one a share:
/// `[2, 1, 1]` makes the first twice as wide as the others.
///
/// With [columns], the row always has that many equal columns, leaving
/// the extra ones empty, so rows on different cards line up.
class InfoRow extends StatelessWidget {
  /// Creates the row.
  const InfoRow({super.key, required this.values, this.flexes, this.columns});

  /// The values, left to right.
  final List<InfoValue> values;

  /// Each value's share of the width, or null for equal shares.
  final List<int>? flexes;

  /// The number of columns to always use, or null for one per value.
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final flexes = this.flexes;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < values.length; index++)
          Expanded(
            flex: flexes == null ? 1 : flexes[index],
            child: Padding(
              // A gap after every value but the last.
              padding: EdgeInsets.only(
                right: index == values.length - 1 ? 0 : 12,
              ),
              child: values[index],
            ),
          ),
        for (var empty = values.length; empty < (columns ?? 0); empty++)
          const Expanded(child: SizedBox()),
      ],
    );
  }
}

/// Plain, muted text for short notes, such as "No naps on this day."
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

/// Red text for a problem the user should know about or fix.
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

/// The red "Delete …" button under a form's main button.
class DeleteButton extends StatelessWidget {
  /// Creates the button with [label], calling [onPressed] when tapped.
  const DeleteButton({super.key, required this.label, required this.onPressed});

  /// For example `Delete this entry`.
  final String label;

  /// What to do when tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
