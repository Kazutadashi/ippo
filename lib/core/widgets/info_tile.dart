// SPDX-License-Identifier: GPL-3.0-or-later

/// A module's tile on the home screen, and labelled numbers.
library;

import 'package:material_ui/material_ui.dart';

import 'section_card.dart';
import 'value_text.dart';

/// One labelled number, such as "Fat" and "6 g".
class TileDetail {
  /// Creates a detail.
  const TileDetail(this.value, {required this.label, this.badge});

  /// The value, for example `6 g`.
  final String value;

  /// What the value is, for example `Fat`.
  final String label;

  /// A small mark after the value, such as `+2`.
  final String? badge;
}

/// One row under a tile's mark: a label at the left and its number at
/// the right edge, such as "Avg (7 days)" and "1326 kcal".
class TileRow {
  /// Creates a row.
  const TileRow(this.label, this.value, {this.isWarning = false});

  /// What the number is.
  final String label;

  /// The number with its unit.
  final String value;

  /// Whether the number is a warning, such as calories over the limit:
  /// it is then shown in the theme's error colour.
  final bool isWarning;
}

/// The value shown when nothing is known yet.
const String unknownTileValue = '–';

/// The gap between two tiles on Home, across and down.
const double tileGap = 8;

/// The room between a tile's edge and its content.
const double tilePadding = 12;

/// The least height of the mark's row, before text scaling: room for
/// two small lines and a bar (Protein, "73 g", and its bar), the
/// tallest mark. Every tile
/// keeps the row, even without a mark, so the grey lines under it start
/// at the same height in every tile.
const double _markRowHeight = 42;

/// A module's tile on Home. Plain information: it never does anything
/// when tapped.
///
/// Every tile has the same four parts, always in the same places, so
/// tiles side by side line up across the page:
///
/// 1. the header: the module's icon and title, small and in capitals;
/// 2. the value: today's, large ("1007 kcal"), with an optional word
///    after it that says what it is ("so far");
/// 3. the mark: one small picture, such as a dot per habit, in a row of
///    fixed height, or a short note in its place when there is nothing
///    to draw;
/// 4. the rows: one or two rows of a grey label and a number, with the
///    numbers lined up at the right edge, the usual always last ("Daily
///    avg (7 days)  1326 kcal").
class HomeTileCard extends StatelessWidget {
  /// Creates the tile.
  const HomeTileCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.valueNote,
    this.mark,
    this.note,
    this.rows = const [],
    this.onTap,
  });

  /// Called when the tile is tapped, such as to open the module's tab;
  /// null for a tile that does nothing.
  final VoidCallback? onTap;

  /// The module's icon, such as `module.buildIcon()`.
  final Widget icon;

  /// The module's title, such as `Food`.
  final String title;

  /// Today's value, or [unknownTileValue].
  final String value;

  /// A word or two after the value, such as `so far`.
  final String? valueNote;

  /// One small picture.
  final Widget? mark;

  /// A note in the mark's place, when there is no mark.
  final String? note;

  /// One or two rows of a label and a number.
  final List<TileRow> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    // Without a mark (nothing logged yet), the note takes its place, so
    // an empty tile has no hole.
    final note = this.note;
    final mark =
        this.mark ??
        (note == null
            ? null
            : Text(
                note,
                style: textTheme.bodySmall?.copyWith(color: muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ));
    // Screen readers read the whole tile as one item: "Food, 1007 kcal
    // so far, …, 7-day avg 1326 kcal".
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        // Tapping the tile opens its tab, when it can.
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              tilePadding,
              10,
              tilePadding,
              tilePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconTheme(
                      data: IconThemeData(size: 14, color: colors.primary),
                      child: icon,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _valueLine(textTheme, muted),
                const SizedBox(height: Spacing.tight),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.textScalerOf(context)
                        .scale(_markRowHeight),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: mark ?? const SizedBox(),
                  ),
                ),
                const SizedBox(height: Spacing.tight),
                for (final row in rows.take(2)) _row(row, textTheme, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One row: the label in grey at the left, the number at the right
  /// edge, so numbers line up down the tile and across a row of tiles.
  Widget _row(TileRow row, TextTheme textTheme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              row.label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.small),
          Text(
            row.value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: row.isWarning ? colors.error : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// The value, large, with its note after it on the same baseline.
  Widget _valueLine(TextTheme textTheme, Color muted) {
    final note = valueNote;
    final big = textTheme.headlineSmall?.copyWith(height: 1.1);
    final small = textTheme.labelLarge?.copyWith(color: muted);
    // A new value fades in, so a change is noticed but calm.
    final valueText = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: KeyedSubtree(
        key: ValueKey(value),
        child: value == unknownTileValue
            // A quiet dash: an empty tile steps back. Screen readers skip
            // it and read the lines instead.
            ? ExcludeSemantics(
                child: Text(value, style: big?.copyWith(color: muted)),
              )
            : ValueText(value, style: big, unitStyle: small),
      ),
    );
    // A value that is too wide shrinks rather than wrapping.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          valueText,
          // The note says what the value is, even before it is known
          // ("– steps").
          if (note != null) ...[
            const SizedBox(width: 6),
            Text(note, style: small),
          ],
        ],
      ),
    );
  }
}

/// Labelled numbers in equal columns, every one aligned left, with a
/// small grey label above each value, such as Protein, Carbs and Fat.
class LabelledValues extends StatelessWidget {
  /// Creates the columns for [details], at most four.
  const LabelledValues({super.key, required this.details});

  /// The values and their labels.
  final List<TileDetail> details;

  @override
  Widget build(BuildContext context) {
    final shown = details.take(4).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < shown.length; index++) ...[
          if (index > 0) const SizedBox(width: Spacing.small),
          Expanded(child: _LabelledValue(detail: shown[index])),
        ],
      ],
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
          detail.label,
          style: textTheme.labelSmall?.copyWith(color: muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Shrink a value that is too wide rather than cutting it off.
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
