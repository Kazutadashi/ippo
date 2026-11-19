// SPDX-License-Identifier: GPL-3.0-or-later

/// A tile of information for the home screen.
library;

import 'package:material_ui/material_ui.dart';

import 'section_card.dart';
import 'value_text.dart';

/// One small fact in a tile's footer.
///
/// With a [label], it is a labelled number, such as "Fat" and "6 g".
/// Without one, it is a line of its own, such as a food's name.
class TileDetail {
  /// Creates a detail.
  const TileDetail(this.value, {this.label, this.color, this.badge});

  /// The fact, for example `6 g` or `Honey`.
  final String value;

  /// What the value is, for example `Fat`, or null for a plain line.
  final String? label;

  /// A colour for a plain line, such as a habit's own colour.
  final Color? color;

  /// A small mark after a labelled value, such as `+2` for a best set
  /// that beat the one before.
  final String? badge;
}

/// The value shown when nothing is known yet.
const String unknownTileValue = '–';

/// The height of a tile's footer, before the user's text size: room for
/// two short lines, or one small picture.
const double _footerHeight = 30;

/// A tile of information for the home screen. Plain information: it
/// never does anything when tapped.
///
/// Every tile has the same three parts, always at the same places, so
/// tiles side by side line up:
///
/// 1. a header: the module's icon and the tile's label, in its colour;
/// 2. the value, digits large and units small ("260 kcal"), with an
///    optional short [valueNote] beside it ("Read"); an empty value
///    leaves this line out;
/// 3. a footer of fixed height holding one thing: a small picture
///    ([visual]), a [note], labelled numbers side by side ("Protein /
///    5 g"), or up to two plain lines ("Honey", then "at 14:43").
///
/// Facts are never joined into one line with "·" or commas.
class InfoTile extends StatelessWidget {
  /// Creates the tile.
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueNote,
    this.details = const [],
    this.note,
    this.color,
    this.visual,
    this.isWide = false,
  });

  /// The icon next to the label: the module's own icon.
  final IconData icon;

  /// What the value is, for example `Last meal`.
  final String label;

  /// The value, shown large; [unknownTileValue] while nothing is known;
  /// empty to leave the value line out.
  final String value;

  /// A short word beside the value, such as the habit a streak belongs
  /// to.
  final String? valueNote;

  /// Small facts for the footer: up to four labelled numbers, or two
  /// plain lines.
  final List<TileDetail> details;

  /// A short note for the footer, such as "Not logged yet".
  final String? note;

  /// The module's colour, already toned for the theme: the icon and
  /// label take it, and the tile gets a soft tint of it. Null for a tile
  /// that belongs to no module, which stays neutral.
  final Color? color;

  /// A small picture for the footer, such as one dot per habit or a
  /// night's sleep as a bar.
  final Widget? visual;

  /// Whether the tile takes a whole row. A wide tile's footer grows to
  /// fit what it holds.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final tint = color;
    final footerHeight = MediaQuery.textScalerOf(context).scale(_footerHeight);
    final footer = _footer(textTheme, muted);
    // Screen readers read the whole tile as one item: "Last meal,
    // 3 h ago, Honey, at 14:43".
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        // A soft tint of the module's colour, so the tiles of one area
        // belong together at a glance.
        color: tint == null
            ? null
            : Color.alphaBlend(
                tint.withValues(alpha: 0.10),
                colors.surfaceContainer,
              ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: tint ?? colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.labelMedium?.copyWith(
                        color: tint ?? muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 2),
                _valueLine(textTheme, muted),
              ],
              const SizedBox(height: 6),
              if (isWide)
                footer
              else
                SizedBox(
                  height: footerHeight,
                  child: Align(alignment: Alignment.centerLeft, child: footer),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The value, with its note beside it.
  Widget _valueLine(TextTheme textTheme, Color muted) {
    final note = valueNote;
    // A new value fades in, so a change is noticed but calm.
    final valueText = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: KeyedSubtree(
        key: ValueKey(value),
        child: value == unknownTileValue
            // A quiet dash: an empty tile steps back. Screen readers skip
            // it and read the note instead.
            ? ExcludeSemantics(
                child: Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(color: muted),
                ),
              )
            : ValueText(
                value,
                style: textTheme.titleLarge,
                unitStyle: textTheme.labelMedium?.copyWith(color: muted),
              ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Shrink a value that is too wide, rather than wrapping it.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: valueText,
          ),
        ),
        if (note != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              note,
              style: textTheme.bodySmall?.copyWith(color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// The footer: one of a picture, a note, labelled numbers or lines.
  Widget _footer(TextTheme textTheme, Color muted) {
    final visual = this.visual;
    if (visual != null) {
      return visual;
    }
    final note = this.note;
    if (note != null || details.isEmpty) {
      return Text(
        note ?? '',
        style: textTheme.bodySmall?.copyWith(color: muted),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (details.every((detail) => detail.label != null)) {
      return LabelledValues(details: details, color: color);
    }
    // Plain lines: the first is the thing itself, in normal text; the
    // second says when or how much, in grey.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < details.length && index < 2; index++)
          Text(
            details[index].value,
            style: textTheme.bodySmall?.copyWith(
              color: details[index].color ?? (index == 0 ? null : muted),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// Labelled numbers side by side, in equal columns: a small grey label
/// above each value, as on the Food screen's Total card.
class LabelledValues extends StatelessWidget {
  /// Creates the columns for [details] (each with a label), at most four.
  const LabelledValues({super.key, required this.details, this.color});

  /// The values and their labels.
  final List<TileDetail> details;

  /// The colour of badges, such as "+2".
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final detail in details.take(4))
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detail.label!,
                  style: textTheme.labelSmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Shrink a value that is too wide ("11:30 pm" in a
                // narrow column) rather than cutting it off.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        detail.value,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                      ),
                      if (detail.badge != null) ...[
                        const SizedBox(width: Spacing.tight),
                        _Badge(text: detail.badge!, color: color),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A small rounded mark, such as `+2`, in the tile's colour.
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
  }
}
