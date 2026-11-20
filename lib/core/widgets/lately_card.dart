// SPDX-License-Identifier: GPL-3.0-or-later

/// Home's "Lately" card: this week against your usual, measure by
/// measure.
library;

import 'package:material_ui/material_ui.dart';

import '../trends.dart';
import 'info_tile.dart';

/// One row per measure: its name, this week's average, the usual over
/// the four weeks before, and an arrow for which way it moved. The arrow
/// only says up or down, never good or bad: more sleep or less food can
/// be either, depending on the person.
///
/// Below, a line on how complete the data is, since a week with gaps
/// says less.
class LatelyCard extends StatelessWidget {
  /// Creates the card.
  const LatelyCard({super.key, required this.trends, required this.daysLogged});

  /// One trend per measure, in the order to show them.
  final List<Trend> trends;

  /// On how many of the last [trendRecentDays] + [trendUsualDays] days anything was
  /// logged.
  final int daysLogged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    final heading = theme.textTheme.labelSmall?.copyWith(
      color: muted,
      letterSpacing: 0.8,
    );
    final hasUsual = trends.any((trend) => trend.usual != null);
    return Card(
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
            // The same header as a tile, with the columns' names.
            Row(
              children: [
                Icon(Icons.insights, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('LATELY', style: heading)),
                SizedBox(
                  width: _valueWidth,
                  child: Text(
                    'THIS WEEK',
                    textAlign: TextAlign.end,
                    style: heading,
                  ),
                ),
                SizedBox(
                  width: _valueWidth,
                  child: Text(
                    'USUAL',
                    textAlign: TextAlign.end,
                    style: heading,
                  ),
                ),
                const SizedBox(width: _arrowWidth),
              ],
            ),
            const SizedBox(height: 6),
            for (final trend in trends) _TrendRow(trend: trend),
            const SizedBox(height: 8),
            Text(
              hasUsual
                  ? 'This week (the last 7 days) against your usual (the 4 '
                        'weeks before). Logged on $daysLogged of those '
                        '${trendRecentDays + trendUsualDays} days.'
                  : 'Your usual shows here after about two weeks of '
                        'logging. Logged on $daysLogged of the last '
                        '${trendRecentDays + trendUsualDays} days.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The width of the "this week" and "usual" columns.
const double _valueWidth = 92;

/// The width of the arrow column.
const double _arrowWidth = 28;

/// One measure's row.
class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    final recent = trend.recent;
    final usual = trend.usual;
    final format = trend.measure.format;
    final (icon, said) = switch (trend.direction) {
      TrendDirection.up => (Icons.arrow_upward, 'up'),
      TrendDirection.down => (Icons.arrow_downward, 'down'),
      TrendDirection.steady => (Icons.arrow_forward, 'about the same'),
      TrendDirection.unknown => (null, 'not known yet'),
    };
    final style = theme.textTheme.bodyMedium;
    return Semantics(
      label:
          '${trend.measure.label}: this week '
          '${recent == null ? 'nothing logged' : format(recent)}, usually '
          '${usual == null ? 'not known yet' : format(usual)}, $said',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                trend.measure.label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: _valueWidth,
              child: _Value(
                text: recent == null ? '–' : format(recent),
                style: recent == null
                    ? style?.copyWith(color: muted)
                    : style?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: _valueWidth,
              child: _Value(
                text: usual == null ? '–' : format(usual),
                style: style?.copyWith(color: muted),
              ),
            ),
            SizedBox(
              width: _arrowWidth,
              child: icon == null
                  ? null
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Icon(icon, size: 16, color: muted),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A value, right-aligned, shrunk to fit if it is long.
class _Value extends StatelessWidget {
  const _Value({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, style: style),
    );
  }
}
