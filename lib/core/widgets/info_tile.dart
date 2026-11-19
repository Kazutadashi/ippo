// SPDX-License-Identifier: GPL-3.0-or-later

/// A tile of information for the home screen.
library;

import 'package:material_ui/material_ui.dart';

import 'section_card.dart';
import 'value_text.dart';

/// One small fact under a tile's value.
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

/// A tile of information for the home screen: an icon and label, a large
/// value, and up to two lines of detail. Plain information: it never
/// does anything when tapped.
///
/// The details are never joined into one line. Either every detail has
/// a label, and they sit side by side as small columns ("Protein / 5 g",
/// "Carbs / 22 g"), or they are plain lines, one fact per line, the most
/// identifying first ("Honey", then "at 14:43"). A [note] replaces the
/// details, for example "Not logged yet".
///
/// Every tile keeps room for two lines of detail, so tiles stay the same
/// height through the day as things are logged.
class InfoTile extends StatelessWidget {
  /// Creates the tile.
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.details = const [],
    this.note,
    this.color,
    this.visual,
  });

  /// The icon next to the label: the module's own icon.
  final IconData icon;

  /// The module's colour, already toned for the theme: the icon and
  /// label take it, and the tile gets a soft tint of it. Null for a tile
  /// that belongs to no module, which stays neutral.
  final Color? color;

  /// A small picture between the value and the details, such as one dot
  /// per habit or a night's sleep as a bar.
  final Widget? visual;

  /// What the value is, for example `Last meal`.
  final String label;

  /// The value, shown large, or [unknownTileValue].
  final String value;

  /// Up to four small facts below the value (four fit on a wide tile).
  final List<TileDetail> details;

  /// A short note shown instead of [details].
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final isUnknown = value == unknownTileValue;
    // Room for two lines of body text, at whatever text size the user
    // chose, so every tile has the same height.
    final bodyStyle = textTheme.bodyMedium!;
    final lineHeight = MediaQuery.textScalerOf(context)
        .scale(bodyStyle.fontSize! * (bodyStyle.height ?? 1.4));
    // Screen readers read the whole tile as one item: "Last meal,
    // 3 h ago, Honey, at 14:43".
    final tint = color;
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
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: tint ?? colors.primary),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.labelLarge?.copyWith(
                        color: tint ?? muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.tight),
              // A new value fades in, so a change is noticed but calm.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, if (current != null) current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(value),
                  child: isUnknown
                      // A quiet dash: an empty tile steps back. Screen
                      // readers skip it and read the note instead.
                      ? ExcludeSemantics(
                          child: Text(
                            value,
                            style: textTheme.headlineSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        )
                      // Shrink a value that is still too wide, rather
                      // than wrapping it.
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: ValueText(
                            value,
                            style: textTheme.headlineSmall,
                            unitStyle: textTheme.titleSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                ),
              ),
              if (visual != null) ...[
                const SizedBox(height: Spacing.small),
                visual!,
              ],
              const SizedBox(height: Spacing.tight),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 2 * lineHeight),
                child: _detailsArea(textTheme, colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsArea(TextTheme textTheme, ColorScheme colors) {
    final note = this.note;
    final muted = colors.onSurfaceVariant;
    if (note != null || details.isEmpty) {
      return Text(
        note ?? '',
        style: textTheme.bodyMedium?.copyWith(color: muted),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final allLabelled = details.every((detail) => detail.label != null);
    if (allLabelled) {
      // Small columns: a grey label above each value, as on the Food
      // screen's Total card.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final detail in details.take(4))
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
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
    // Plain lines: the first is the thing itself, in normal text; the
    // second says when or how much, in grey.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < details.length && index < 2; index++)
          Text(
            details[index].value,
            style: textTheme.bodyMedium?.copyWith(
              color: details[index].color ?? (index == 0 ? null : muted),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
  }
}
