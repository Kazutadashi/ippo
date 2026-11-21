// SPDX-License-Identifier: GPL-3.0-or-later

/// Nutrients against their normal daily amounts, as small bars.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../../../core/widgets/section_card.dart';
import '../daily_references.dart';
import '../nutrients.dart';

/// One nutrient's amount against its daily [reference].
class NutrientAmount {
  /// Creates the amount for the nutrient [key].
  const NutrientAmount(this.key, this.label, this.amount, this.reference);

  /// The nutrient's field name, such as `proteins_g`.
  final String key;

  /// The name on screen, such as `Protein`.
  final String label;

  /// How much was eaten, or null if not known.
  final double? amount;

  /// The normal amount a day, or null if there is none.
  final double? reference;

  /// The unit, such as `g`.
  String get unit => nutrientKindOf(key)?.unit ?? '';

  /// How much of the daily amount this is: 1 is all of it, more is over.
  double get share {
    final amount = this.amount;
    final reference = this.reference;
    if (amount == null || reference == null || reference <= 0) {
      return 0;
    }
    return amount / reference;
  }
}

/// Writes an amount with its unit, whole from 10 on: `73 g`, `2.5 mg`.
String formatNutrientAmount(double amount, String unit) {
  final number = amount >= 10 ? '${amount.round()}' : formatAmount(amount);
  return '$number $unit';
}

/// A thin bar as full as [share], in the accent colour on a pale track.
/// Past 1 it is full; for a most ([isLimit], such as fat or salt) it
/// then turns red, the theme's colour for problems, so going over shows
/// at a glance. For a least (protein, fibre) more is fine: it stays in
/// the accent colour.
class ShareBar extends StatelessWidget {
  /// Creates the bar.
  const ShareBar({
    super.key,
    required this.share,
    this.height = 4,
    this.isLimit = true,
  });

  /// How full: 0 empty, 1 full; more than 1 is over.
  final double share;

  /// How thick.
  final double height;

  /// Whether the daily amount is a most, so going past it is red.
  final bool isLimit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOver = isLimit && share > 1;
    final color = isOver ? colors.error : colors.primary;
    final filled = (share.clamp(0.0, 1.0) * 1000).round();
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      // Flex parts rather than measured widths, so a tile's height can
      // be worked out before it is laid out.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filled > 0)
            Expanded(
              flex: filled,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          if (filled < 1000) Spacer(flex: 1000 - filled),
        ],
      ),
    );
  }
}

/// Nutrients side by side in equal columns: a small grey label, the
/// amount, and a thin bar of how much of the daily amount it is. With
/// [showsReference], "of 50 g" under each bar says what full means.
class NutrientBars extends StatelessWidget {
  /// Creates the columns.
  const NutrientBars({
    super.key,
    required this.amounts,
    this.showsReference = false,
  });

  /// The nutrients, left to right.
  final List<NutrientAmount> amounts;

  /// Whether to write the daily amount under each bar.
  final bool showsReference;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < amounts.length; index++) ...[
          if (index > 0) const SizedBox(width: Spacing.small),
          Expanded(child: _column(amounts[index], textTheme, muted)),
        ],
      ],
    );
  }

  Widget _column(NutrientAmount nutrient, TextTheme textTheme, Color muted) {
    final amount = nutrient.amount;
    final reference = nutrient.reference;
    return Semantics(
      label:
          '${nutrient.label}: '
          '${amount == null ? 'not known' : formatNutrientAmount(amount, nutrient.unit)}'
          '${reference == null ? '' : ' of ${formatNutrientAmount(reference, nutrient.unit)} a day'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nutrient.label,
            style: textTheme.labelSmall?.copyWith(color: muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount == null
                  ? '–'
                  : formatNutrientAmount(amount, nutrient.unit),
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (reference != null) ...[
            const SizedBox(height: 3),
            ShareBar(
              share: nutrient.share,
              isLimit: isLimitNutrient(nutrient.key),
            ),
            if (showsReference)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'of ${formatNutrientAmount(reference, nutrient.unit)}',
                  style: textTheme.labelSmall?.copyWith(color: muted),
                  maxLines: 1,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
