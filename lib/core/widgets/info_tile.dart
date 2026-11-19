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
  const TileDetail(this.value, {this.label, this.badge});

  /// The fact, for example `6 g` or `Honey`.
  final String value;

  /// What the value is, for example `Fat`, or null for a plain line.
  final String? label;

  /// A small mark after a labelled value, such as `+2` for a best set
  /// that beat the one before.
  final String? badge;
}

/// The value shown when nothing is known yet.
const String unknownTileValue = '–';

/// A tile of information for the home screen. Plain information: it
/// never does anything when tapped.
///
/// Every tile is built from the same rows, and each row uses the
/// tile's whole width, with one thing at the left edge and, when there
/// is one, another at the right edge:
///
/// 1. the header: the module's icon and the tile's label on the left,
///    and an optional short [labelNote] on the right ("Read");
/// 2. the value, digits large and units small ("260 kcal"), with an
///    optional small picture ([aside]) on the right, such as one dot
///    per habit; an empty value leaves this row out;
/// 3. a footer, right under the value, holding one thing: a picture
///    that takes the whole width ([visual]), a [note], labelled numbers
///    spread across the width ("Protein / 5 g"), or up to two plain
///    lines ("Honey", then "at 14:43").
///
/// Colours come from the theme, so every tile looks like part of one
/// app. Facts are never joined into one line with "·" or commas.
class InfoTile extends StatelessWidget {
  /// Creates the tile.
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.labelNote,
    this.aside,
    this.details = const [],
    this.note,
    this.visual,
    this.isWide = false,
  });

  /// The icon next to the label: the module's own icon.
  final IconData icon;

  /// What the value is, for example `Last meal`.
  final String label;

  /// The value, shown large; [unknownTileValue] while nothing is known;
  /// empty to leave the value row out.
  final String value;

  /// A short word at the right of the header, such as the habit a
  /// streak belongs to.
  final String? labelNote;

  /// A small picture at the right of the value, such as one dot per
  /// habit.
  final Widget? aside;

  /// Small facts for the footer: up to four labelled numbers, or two
  /// plain lines.
  final List<TileDetail> details;

  /// A short note for the footer, such as "Not logged yet".
  final String? note;

  /// A picture for the footer, as wide as the tile, such as a night's
  /// sleep as a bar.
  final Widget? visual;

  /// Whether the tile takes a whole row.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final footer = _footer(textTheme, muted);
    final labelNote = this.labelNote;
    // Screen readers read the whole tile as one item: "Last meal,
    // 3 h ago, Honey, at 14:43".
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.labelMedium?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (labelNote != null) ...[
                    const SizedBox(width: Spacing.tight),
                    // Half the header, so the label still shows; the
                    // note ends at the right edge.
                    Expanded(
                      child: Text(
                        labelNote,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ],
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 2),
                _valueRow(textTheme, muted),
              ],
              if (footer != null) ...[const SizedBox(height: 6), footer],
            ],
          ),
        ),
      ),
    );
  }

  /// The value at the left, with the [aside] at the right.
  Widget _valueRow(TextTheme textTheme, Color muted) {
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
                  style: textTheme.titleLarge?.copyWith(
                    color: muted,
                    height: 1.15,
                  ),
                ),
              )
            : ValueText(
                value,
                style: textTheme.titleLarge?.copyWith(height: 1.15),
                unitStyle: textTheme.labelMedium?.copyWith(color: muted),
              ),
      ),
    );
    final aside = this.aside;
    if (aside == null) {
      // A value that is too wide shrinks rather than wrapping.
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: valueText,
      );
    }
    // A value beside a picture is short ("3 of 4"), so it keeps its
    // size; the picture gets the rest of the row and sits at its right
    // edge, wrapping onto a second line if it must.
    return Row(
      children: [
        valueText,
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: aside),
        ),
      ],
    );
  }

  /// The footer: one of a picture, a note, labelled numbers or lines;
  /// null when there is nothing to show.
  Widget? _footer(TextTheme textTheme, Color muted) {
    final visual = this.visual;
    if (visual != null) {
      return visual;
    }
    final note = this.note;
    if (note != null) {
      return Text(
        note,
        style: textTheme.bodySmall?.copyWith(color: muted),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (details.isEmpty) {
      return null;
    }
    if (details.every((detail) => detail.label != null)) {
      return LabelledValues(details: details);
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
              color: index == 0 ? null : muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// Labelled numbers spread across the whole width: a small grey label
/// above each value, as on the Food screen's Total card. The first sits
/// at the left edge, the last at the right edge, and any others evenly
/// between, so the row is balanced rather than bunched at the left.
class LabelledValues extends StatelessWidget {
  /// Creates the columns for [details] (each with a label), at most four.
  const LabelledValues({super.key, required this.details});

  /// The values and their labels.
  final List<TileDetail> details;

  @override
  Widget build(BuildContext context) {
    final shown = details.take(4).toList();
    return Row(
      mainAxisAlignment: shown.length == 1
          ? MainAxisAlignment.start
          : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < shown.length; index++)
          Flexible(
            child: _LabelledValue(
              detail: shown[index],
              // Each column lines up with its own edge of the row.
              alignment: shown.length == 1 || index == 0
                  ? CrossAxisAlignment.start
                  : index == shown.length - 1
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
            ),
          ),
      ],
    );
  }
}

/// One small grey label with its value under it.
class _LabelledValue extends StatelessWidget {
  const _LabelledValue({required this.detail, required this.alignment});

  final TileDetail detail;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final badge = detail.badge;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          detail.label!,
          style: textTheme.labelSmall?.copyWith(color: muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Shrink a value that is too wide ("11:30 pm" in a narrow
        // column) rather than cutting it off.
        FittedBox(
          fit: BoxFit.scaleDown,
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
              if (badge != null) ...[
                const SizedBox(width: Spacing.tight),
                _Badge(text: badge),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small rounded mark, such as `+2`, in the theme's accent colour.
class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).colorScheme.primary;
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
