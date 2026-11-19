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
///
/// Spacing comes from one small scale, so gaps inside a card are always
/// smaller than gaps between cards: see [Spacing].
library;

import 'package:material_ui/material_ui.dart';

/// The spacing scale. Every gap and padding in the app is one of these.
abstract final class Spacing {
  /// Between closely related things: a label and its value.
  static const double tight = 4;

  /// Between things in one group: fields side by side, rows in a card,
  /// and between cards.
  static const double small = 8;

  /// Inside a card's edge, and between groups within a card.
  static const double medium = 12;

  /// At the screen's left and right edges.
  static const double screen = 16;
}

/// A card holding one section of a screen, with the same margins and
/// padding everywhere. Its children fill the card's width.
class SectionCard extends StatelessWidget {
  /// Creates a card with [children], usually starting with a
  /// [CardHeader].
  const SectionCard({super.key, required this.children});

  /// What the card holds, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: Spacing.small),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
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
    this.icon,
    this.iconWidget,
    required this.title,
    this.action,
  }) : assert(icon != null || iconWidget != null);

  /// The icon before the title.
  final IconData? icon;

  /// A drawn icon instead of [icon], such as a module's own.
  final Widget? iconWidget;

  /// The title.
  final String title;

  /// A button shown on the right, if any.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return SizedBox(
      // The same height with or without a button, so cards line up.
      height: 36,
      child: Row(
        children: [
          IconTheme(
            data: IconThemeData(
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            child: iconWidget ?? Icon(icon),
          ),
          const SizedBox(width: Spacing.medium),
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
          child: Text(value, style: textTheme.titleMedium),
        ),
      ],
    );
  }
}

/// Information that may be long, such as a folder path: a small grey
/// label above the text, which wraps instead of shrinking.
///
/// With [isSelectable], the text can be selected and copied, which helps
/// for ids and paths. With [isSmallPrint], it is small and grey, for
/// details such as a long id that few people need to read.
class InfoText extends StatelessWidget {
  /// Creates the information block.
  const InfoText({
    super.key,
    required this.label,
    required this.text,
    this.isSelectable = false,
    this.isSmallPrint = false,
  });

  /// What the text is.
  final String label;

  /// The text itself.
  final String text;

  /// Whether the text can be selected and copied.
  final bool isSelectable;

  /// Whether the text is small print.
  final bool isSmallPrint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = isSmallPrint
        ? textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : textTheme.bodyMedium;
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
        if (isSelectable)
          SelectableText(text, style: style)
        else
          Text(text, style: style),
      ],
    );
  }
}

/// A small grey label above a control, such as "Theme" above a choice
/// of light or dark.
class FieldLabel extends StatelessWidget {
  /// Creates the label.
  const FieldLabel(this.text, {super.key});

  /// The label.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
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

/// The Save button for the top bar of a form screen. Kept at the top, it
/// is always in reach, however long the form (as in Material's
/// full-screen dialogs).
class AppBarSaveButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] when tapped. With
  /// [onPressed] null, it is shown disabled.
  const AppBarSaveButton({super.key, required this.onPressed});

  /// What to do when tapped.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilledButton(onPressed: onPressed, child: const Text('Save')),
    );
  }
}
