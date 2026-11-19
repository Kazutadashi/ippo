// SPDX-License-Identifier: GPL-3.0-or-later

/// Home's week grid: a row per module, a column per day, one mark each.
library;

import 'package:material_ui/material_ui.dart';

import '../module.dart';
import 'info_tile.dart';

/// One labelled row of the grid.
typedef WeekGridRow = ({String title, IconData icon, WeekRow row});

/// The width of the column of row names ("Habits", "Exercise").
const double _nameWidth = 84;

/// The height of one row of marks.
const double _rowHeight = 22;

/// The size of a dot, and the greatest height of a bar.
const double _markSize = 12;

/// The last seven days at a glance: the days across the top (today's
/// picked out in the accent colour), and under them one row per module,
/// named on the left, with one mark per day. No numbers: the tiles below
/// have them. The names say what each row of marks means.
class WeekGrid extends StatelessWidget {
  /// Creates the grid for the seven days ending on [day].
  const WeekGrid({super.key, required this.day, required this.rows});

  /// The last day shown, in the right-hand column.
  final DateTime day;

  /// The rows, one per module that has one.
  final List<WeekGridRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = weekEndingOn(day);
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
            // The same header as a tile.
            Row(
              children: [
                Icon(Icons.date_range, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'LAST 7 DAYS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // The days, over their columns.
            Row(
              children: [
                const SizedBox(width: _nameWidth),
                for (final column in days)
                  Expanded(
                    child: Text(
                      letters[column.weekday - 1],
                      textAlign: TextAlign.center,
                      style: column == day
                          // The day shown stands out, as the newest.
                          ? theme.textTheme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            )
                          : theme.textTheme.labelMedium?.copyWith(color: muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final row in rows) _row(context, row),
          ],
        ),
      ),
    );
  }

  /// One module's row: its name, then a mark per day.
  Widget _row(BuildContext context, WeekGridRow row) {
    final theme = Theme.of(context);
    return Semantics(
      label: row.row.description,
      excludeSemantics: true,
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _nameWidth,
              child: Text(
                row.title,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final value in row.row.values.take(7))
              Expanded(
                child: Center(
                  child: row.row.shape == WeekMarkShape.dot
                      ? _Dot(value: value)
                      : _Bar(value: value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A circle as full as [value]: a ring for 0 or no data, a pale fill
/// growing stronger towards 1, which is solid.
class _Dot extends StatelessWidget {
  const _Dot({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final share = (value ?? 0).clamp(0.0, 1.0);
    return Container(
      width: _markSize,
      height: _markSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: share == 0 ? null : color.withValues(alpha: 0.3 + 0.7 * share),
        border: share == 0
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
    );
  }
}

/// A small upright bar as tall as [value], standing on a common base
/// line; a short dash for a day without data.
class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final value = this.value;
    return SizedBox(
      height: _rowHeight - 4,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: value == null
            ? Container(
                width: 6,
                height: 2,
                color: color.withValues(alpha: 0.4),
              )
            : Container(
                width: 6,
                height: 3 + (_rowHeight - 7) * value.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
      ),
    );
  }
}
