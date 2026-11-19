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

/// The room between a tile's edge and its content.
const double tilePadding = 12;

/// The gap between two tiles on Home, across and down.
const double tileGap = 8;

/// The gap between the two halves of a wide tile. It is the gap between
/// two half tiles plus their inner padding, so a wide tile's right half
/// starts exactly where the right-hand tile's content starts.
const double halfTileGap = tileGap + 2 * tilePadding;

/// The least height of the value row, before text scaling: room for a
/// large value, or two rows of habit dots beside it.
const double _valueSlotHeight = 30;

/// A tile of information for the home screen. Plain information: it
/// never does anything when tapped.
///
/// Every tile is built from the same three slots. The label and the
/// value slots have the same height in every tile, so labels, values
/// and the tops of footers form straight lines across Home. An empty tile keeps the same slots, with "–" as its
/// value and its note where the footer goes:
///
/// 1. the header: the module's icon and the tile's label on the left,
///    and an optional short [labelNote] on the right ("Read");
/// 2. the value, digits large and units small ("260 kcal"), with an
///    optional small picture ([aside]) on the right, such as one dot
///    per habit; an empty value leaves this row out;
/// 3. a footer, right under the value, holding one thing: a picture
///    that takes the whole width ([visual]), a [note], labelled numbers
///    in equal columns ("Protein / 5 g"), or up to two plain lines
///    ("Honey", then "at 14:43"). A wide tile puts labelled numbers in
///    two halves that line up with the half tiles below it.
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
    final scaler = MediaQuery.textScalerOf(context);
    final labelNote = this.labelNote;
    final labelText = Text(
      label,
      style: textTheme.labelMedium?.copyWith(color: muted),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // Screen readers read the whole tile as one item: "Last meal,
    // 3 h ago, Honey, at 14:43".
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(tilePadding, 8, tilePadding, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  // With a note beside it, the label (a short word such
                  // as "Streaks") keeps its width and the note gets the
                  // rest; alone, it takes the whole row.
                  if (labelNote == null)
                    Expanded(child: labelText)
                  else
                    labelText,
                  if (labelNote != null) ...[
                    const SizedBox(width: Spacing.small),
                    // The note ends at the right edge.
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
                // The value slot: always as tall, with the value in its
                // middle, so values line up across a row.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: scaler.scale(_valueSlotHeight),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _valueRow(textTheme, muted),
                  ),
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 4),
                // The footer starts right under the value slot, so footers
                // start on one line across a row.
                footer,
              ],
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
      return isWide
          ? WideLabelledValues(details: details)
          : LabelledValues(details: details);
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

/// Labelled numbers in equal columns, every one aligned left, with a
/// small grey label above each value, as on the Food screen's Total
/// card. With more details than [columns], they continue on a second
/// row, in the same columns.
class LabelledValues extends StatelessWidget {
  /// Creates the columns for [details] (each with a label), at most four.
  /// [columns] defaults to one per detail.
  const LabelledValues({super.key, required this.details, this.columns});

  /// The values and their labels.
  final List<TileDetail> details;

  /// How many columns a row has.
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final shown = details.take(4).toList();
    final perRow = columns ?? shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var start = 0; start < shown.length; start += perRow) ...[
          if (start > 0) const SizedBox(height: Spacing.tight),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < perRow; column++) ...[
                if (column > 0) const SizedBox(width: Spacing.small),
                Expanded(
                  child: start + column < shown.length
                      ? _LabelledValue(detail: shown[start + column])
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// A wide tile's two halves, which line up with the two half tiles
/// below it: [left] starts at the left tile's content, [right] at the
/// right tile's. With [hasDivider], a thin line runs between them.
class TileHalves extends StatelessWidget {
  /// Creates the halves.
  const TileHalves({
    super.key,
    required this.left,
    required this.right,
    this.hasDivider = false,
  });

  /// The left half.
  final Widget left;

  /// The right half.
  final Widget right;

  /// Whether a thin line separates the halves.
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight makes the row as tall as its taller half, so the
    // line runs their full height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          hasDivider
              ? const VerticalDivider(width: halfTileGap)
              : const SizedBox(width: halfTileGap),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// Labelled numbers for a wide tile, split over its two [TileHalves]:
/// one in each half for up to two, else two columns in each half, so
/// every number lines up with the tiles below.
class WideLabelledValues extends StatelessWidget {
  /// Creates the values for [details] (each with a label), at most four.
  const WideLabelledValues({super.key, required this.details});

  /// The values and their labels.
  final List<TileDetail> details;

  @override
  Widget build(BuildContext context) {
    final shown = details.take(4).toList();
    final perHalf = shown.length <= 2 ? 1 : 2;
    final left = shown.take(perHalf).toList();
    final right = shown.skip(perHalf).toList();
    return TileHalves(
      left: Align(
        alignment: Alignment.topLeft,
        child: LabelledValues(details: left, columns: perHalf),
      ),
      right: Align(
        alignment: Alignment.topLeft,
        child: right.isEmpty
            ? const SizedBox()
            : LabelledValues(details: right, columns: perHalf),
      ),
    );
  }
}

/// One small grey label with its value under it.
class _LabelledValue extends StatelessWidget {
  const _LabelledValue({required this.detail});

  final TileDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final badge = detail.badge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
