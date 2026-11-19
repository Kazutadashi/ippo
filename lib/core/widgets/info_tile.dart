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

/// The value shown when nothing is known yet.
const String unknownTileValue = '–';

/// The gap between two tiles on Home, across and down.
const double tileGap = 8;

/// The room between a tile's edge and its content.
const double tilePadding = 12;

/// The least height of the mark's row, before text scaling: room for
/// two small lines (Protein over "73 g"), the tallest mark. Every tile
/// keeps the row, even without a mark, so the grey lines under it start
/// at the same height in every tile.
const double _markRowHeight = 36;

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
///    fixed height;
/// 4. the lines: one or two short grey lines, such as "Last meal 8 h
///    ago", with the comparison to the usual always last ("7-day avg
///    1326 kcal").
class HomeTileCard extends StatelessWidget {
  /// Creates the tile.
  const HomeTileCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.valueNote,
    this.mark,
    this.lines = const [],
  });

  /// The module's icon.
  final IconData icon;

  /// The module's title, such as `Food`.
  final String title;

  /// Today's value, or [unknownTileValue].
  final String value;

  /// A word or two after the value, such as `so far`.
  final String? valueNote;

  /// One small picture.
  final Widget? mark;

  /// One or two short grey lines.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    // Without a mark (nothing logged yet), the first line takes its
    // place, so an empty tile has no hole and the last line still lines
    // up with the tile beside it.
    final lineStyle = textTheme.bodySmall?.copyWith(color: muted);
    final firstLineAsMark = this.mark == null && lines.isNotEmpty;
    final mark = firstLineAsMark
        ? Text(
            lines.first,
            style: lineStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        : this.mark;
    final shownLines = (firstLineAsMark ? lines.skip(1) : lines).take(2);
    // Screen readers read the whole tile as one item: "Food, 1007 kcal
    // so far, …, 7-day avg 1326 kcal".
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
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
                  Icon(icon, size: 14, color: colors.primary),
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
              for (final line in shownLines)
                Text(
                  line,
                  style: lineStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
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
          if (note != null && value != unknownTileValue) ...[
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
