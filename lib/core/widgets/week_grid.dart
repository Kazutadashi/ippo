// SPDX-License-Identifier: GPL-3.0-or-later

/// Home's week grid: a row per module, a column per day, one value each.
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

/// The last seven days at a glance: the days across the top (today's
/// picked out in the accent colour), and under them one row per module,
/// named with its unit on the left ("Sleep (h)"), with one value per
/// day, like a small table.
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

  /// One module's row: its name with its unit, then a value per day,
  /// the day shown in the accent colour, and a quiet dash for a day
  /// without data.
  Widget _row(BuildContext context, WeekGridRow row) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cells = row.row.cells.take(7).toList();
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
                row.row.label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (var index = 0; index < cells.length; index++)
              Expanded(
                child: _cell(
                  context,
                  cells[index],
                  isDayShown: index == cells.length - 1,
                  colors: colors,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One day's value, shrunk to fit its narrow column if it must.
  Widget _cell(
    BuildContext context,
    String? value, {
    required bool isDayShown,
    required ColorScheme colors,
  }) {
    final style = Theme.of(context).textTheme.labelMedium;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value ?? '–',
        style: value == null
            ? style?.copyWith(color: colors.onSurfaceVariant)
            : isDayShown
            ? style?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              )
            : style,
      ),
    );
  }
}
