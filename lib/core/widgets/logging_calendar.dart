// SPDX-License-Identifier: GPL-3.0-or-later

/// Home's logging calendar: one square per day for the last months,
/// darker the more was logged, like a contribution graph.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'info_tile.dart';
import 'section_card.dart';

/// The size of one day's square.
const double _square = 12;

/// The gap between squares.
const double _gap = 3;

/// The width of the weekday letters on the left.
const double _letterWidth = 14;

/// The last months of logging, one square per day: weeks are columns
/// (oldest on the left), weekdays rows (Monday at the top). A square is
/// as dark as the share of areas logged that day, so days with gaps in
/// the data stand out, and a day with everything logged is solid. It
/// shows as many weeks as fit the width.
///
/// The data is the point of Ippo, so this is what keeps it complete:
/// a pale square is a day to fill in.
class LoggingCalendar extends StatelessWidget {
  /// Creates the calendar ending on [day].
  const LoggingCalendar({
    super.key,
    required this.day,
    required this.loggedAreas,
    required this.areaNames,
  });

  /// The last day shown.
  final DateTime day;

  /// For each day (`YYYY-MM-DD`) with anything logged, how many areas
  /// (habits, food, ...) have data.
  final Map<String, int> loggedAreas;

  /// The areas, such as Habits and Food, named in the explanation.
  final List<String> areaNames;

  /// How many areas there are, for a full square.
  int get areaCount => areaNames.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    final small = theme.textTheme.labelSmall?.copyWith(color: muted);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          tilePadding,
          10,
          tilePadding,
          tilePadding,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Each week takes a gap and a square, after the letters.
            final weeks =
                ((constraints.maxWidth - _letterWidth) / (_square + _gap))
                    .floor()
                    .clamp(1, 53);
            // The Monday of the week [day] is in, and of the first week.
            final lastMonday = addDays(day, -(day.weekday - 1));
            final firstMonday = addDays(lastMonday, -7 * (weeks - 1));
            final logged = loggedAreas.keys
                .where((date) => date.compareTo(formatDate(firstMonday)) >= 0)
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view, size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'DAYS LOGGED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text('$logged of ${weeks * 7} days', style: small),
                  ],
                ),
                const SizedBox(height: Spacing.tight),
                // Says what the squares are, for someone seeing them for
                // the first time.
                Text(
                  'Each square is one day. The more of '
                  '${_listOf(areaNames)} you logged that day, the darker '
                  'it is.',
                  style: small,
                ),
                const SizedBox(height: Spacing.small),
                Semantics(
                  label:
                      'Days logged: $logged of the last ${weeks * 7} days '
                      'have something logged',
                  excludeSemantics: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _weekdayLetters(small),
                      for (var week = 0; week < weeks; week++)
                        Padding(
                          padding: const EdgeInsets.only(left: _gap),
                          child: Column(
                            children: [
                              for (var weekday = 0; weekday < 7; weekday++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: weekday == 0 ? 0 : _gap,
                                  ),
                                  child: _dayOf(
                                    addDays(firstMonday, week * 7 + weekday),
                                    colors,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.small),
                _legend(colors, small),
              ],
            );
          },
        ),
      ),
    );
  }

  /// M, W and F beside their rows, as on a contribution graph.
  Widget _weekdayLetters(TextStyle? style) {
    const letters = ['M', '', 'W', '', 'F', '', ''];
    return SizedBox(
      width: _letterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var weekday = 0; weekday < 7; weekday++)
            Padding(
              padding: EdgeInsets.only(top: weekday == 0 ? 0 : _gap),
              child: SizedBox(
                height: _square,
                child: FittedBox(child: Text(letters[weekday], style: style)),
              ),
            ),
        ],
      ),
    );
  }

  /// One day's square: empty after [day], pale for nothing logged, and
  /// darker the more areas have data. The day shown has a ring.
  Widget _dayOf(DateTime date, ColorScheme colors) {
    // A day still to come: an empty outline, so every day has a square.
    if (date.isAfter(day)) {
      return Container(
        width: _square,
        height: _square,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: colors.surfaceContainerHighest),
        ),
      );
    }
    final count = loggedAreas[formatDate(date)] ?? 0;
    return Container(
      width: _square,
      height: _square,
      decoration: BoxDecoration(
        color: _shade(count, colors),
        borderRadius: BorderRadius.circular(2),
        border: date == day
            ? Border.all(color: colors.onSurface, width: 1.5)
            : null,
      ),
    );
  }

  /// The colour for [count] areas logged: the card's own grey for none,
  /// then the accent, stronger with each area.
  Color _shade(int count, ColorScheme colors) {
    if (count == 0) {
      return colors.surfaceContainerHighest;
    }
    final share = (count / areaCount).clamp(0.0, 1.0);
    return colors.primary.withValues(alpha: 0.25 + 0.75 * share);
  }

  /// "None" and "All 4" with the shades between, so the colours explain
  /// themselves.
  Widget _legend(ColorScheme colors, TextStyle? style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('None', style: style),
        const SizedBox(width: Spacing.tight),
        for (var count = 0; count <= areaCount; count++)
          Padding(
            padding: const EdgeInsets.only(left: _gap),
            child: Container(
              width: _square,
              height: _square,
              decoration: BoxDecoration(
                color: _shade(count, colors),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: Spacing.tight),
        Text('All $areaCount', style: style),
      ],
    );
  }
}

/// Names joined for a sentence: "habits, food, exercise and sleep".
String _listOf(List<String> names) {
  final lower = [for (final name in names) name.toLowerCase()];
  if (lower.length < 2) {
    return lower.join();
  }
  return '${lower.sublist(0, lower.length - 1).join(', ')} and ${lower.last}';
}
