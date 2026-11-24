// SPDX-License-Identifier: GPL-3.0-or-later

/// Home's week grid: a row per module, a column per day, one value each.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import '../module.dart';
import 'info_tile.dart';

/// One labeled row of the grid.
typedef WeekGridRow = ({String title, IconData icon, WeekRow row});

/// The width of the column of row names ("Habits", "Exercise").
const double _nameWidth = 84;

/// The height of one row of marks.
const double _rowHeight = 22;

/// Seven days at a glance: the days across the top, and under them one
/// row per module, named with its unit on the left ("Sleep (h)"), with
/// one value per day, like a small table. The day shown is picked out
/// in the accent color, with a soft column behind it; tapping another
/// day's column shows that day, and the seven days stay where they are.
class WeekGrid extends StatelessWidget {
  /// Creates the grid for the seven days ending on [end], with [day]
  /// (one of them) picked out.
  const WeekGrid({
    super.key,
    required this.end,
    required this.day,
    required this.rows,
    required this.onDaySelected,
    this.onOpenCharts,
  });

  /// The last of the seven days, in the right-hand column.
  final DateTime end;

  /// The day shown on Home, one of the seven: picked out.
  final DateTime day;

  /// The rows, one per module that has one.
  final List<WeekGridRow> rows;

  /// Called with a day when its column is tapped, to show that day.
  final ValueChanged<DateTime> onDaySelected;

  /// Opens the charts, from a button in the card's header: the week is a
  /// small chart of the days, the charts show every day. Null for none.
  final VoidCallback? onOpenCharts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = weekEndingOn(end);
    // The column of the day shown (the last one if it is not among them).
    final shownIndex = days.contains(day) ? days.indexOf(day) : days.length - 1;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tilePadding,
          // The Charts link's row is 48 high for its tap area, so it
          // starts at the top: its text then sits where a header's does.
          onOpenCharts == null ? 10 : 0,
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
                // A real button, so the charts are hard to miss, but sized
                // to the header: a small tonal pill on the header's line.
                // Its tap area is still 48 high.
                if (onOpenCharts != null)
                  FilledButton.tonalIcon(
                    onPressed: onOpenCharts,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: theme.textTheme.labelLarge,
                    ),
                    icon: const Icon(Icons.bar_chart, size: 18),
                    label: const Text('Charts'),
                  ),
              ],
            ),
            if (onOpenCharts == null) const SizedBox(height: 6),
            // The day shown has a soft column behind it, top to bottom,
            // as on the Habits grid, so it is easy to find.
            LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = (constraints.maxWidth - _nameWidth) / 7;
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: _nameWidth + shownIndex * columnWidth,
                      width: columnWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                      // The day shown stands out.
                                      ? theme.textTheme.labelMedium?.copyWith(
                                          color: colors.primary,
                                          fontWeight: FontWeight.bold,
                                        )
                                      : theme.textTheme.labelMedium?.copyWith(
                                          color: muted,
                                        ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final row in rows) _row(context, row, shownIndex),
                      ],
                    ),
                    // Each day's column, top to bottom, is a button that
                    // shows that day, as the day bar's arrows do.
                    for (var index = 0; index < days.length; index++)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: _nameWidth + index * columnWidth,
                        width: columnWidth,
                        child: Semantics(
                          button: true,
                          label: 'Show ${formatShortDate(days[index])}',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onDaySelected(days[index]),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One module's row: its name with its unit, then a value per day,
  /// the day shown in the accent color, and a quiet dash for a day
  /// without data.
  Widget _row(BuildContext context, WeekGridRow row, int shownIndex) {
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
                  isDayShown: index == shownIndex,
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
        // No data: a quiet dash. The day shown: bold, in the accent.
        // Other days: a little quieter, so the day shown stands out.
        style: value == null
            ? style?.copyWith(color: colors.onSurfaceVariant)
            : isDayShown
            ? style?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              )
            : style?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w400,
              ),
      ),
    );
  }
}
