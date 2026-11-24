// SPDX-License-Identifier: GPL-3.0-or-later

/// The top bar of the Habits, Food, Exercise and Sleep tabs, and the row
/// with the date and the day bar that Home shares with them.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'day_bar.dart';
import 'section_card.dart';

/// How tall the row with the date and the day bar is.
const double _dayRowHeight = 48;

/// From this width on (in logical pixels), the date and the day bar sit
/// on the title's row.
const double _wideBar = 600;

/// Narrower than this (in logical pixels), the date is written short.
const double _narrowWidth = 400;

/// A tab's top bar: the tab's name and its buttons, as a plain [AppBar]
/// in the theme's colors. Only Home has the landscape; the tabs stay
/// plain, so their content leads.
///
/// For a tab about one [day], the date and the day bar go on a row under
/// the title, or, on a wide window (a phone on its side, a tablet, a
/// desktop), on the title's own row, which leaves more of a short screen
/// to the page. [onDayChanged] is called with a newly chosen day.
PreferredSizeWidget tabAppBar(
  BuildContext context, {
  required Widget title,
  List<Widget>? actions,
  DateTime? day,
  ValueChanged<DateTime>? onDayChanged,
}) {
  if (day == null) {
    return AppBar(title: title, actions: actions);
  }
  if (MediaQuery.sizeOf(context).width >= _wideBar) {
    return AppBar(
      title: title,
      actions: [
        _DateText(day: day),
        const SizedBox(width: Spacing.medium),
        DayBar(day: day, onChanged: onDayChanged!),
        ...?actions,
      ],
    );
  }
  return AppBar(
    title: title,
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(_dayRowHeight),
      child: SizedBox(
        height: _dayRowHeight,
        child: DayRow(day: day, onChanged: onDayChanged!),
      ),
    ),
  );
}

/// The date on the left and the day bar on the right: under a tab's
/// title, and under Home's landscape, so both look the same.
class DayRow extends StatelessWidget {
  /// Creates the row for [day], reporting a newly chosen day to
  /// [onChanged].
  const DayRow({super.key, required this.day, required this.onChanged});

  /// The day shown.
  final DateTime day;

  /// Called with a newly chosen day.
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          // One line: a long date shrinks a little rather than wrap.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _DateText(day: day),
            ),
          ),
          DayBar(day: day, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The date as the day rows write it: "Saturday, 21 Nov", or on a narrow
/// phone the short form, "Sat 21 Nov", so it keeps its size beside the
/// day bar.
class _DateText extends StatelessWidget {
  const _DateText({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      MediaQuery.sizeOf(context).width < _narrowWidth
          ? formatShortDate(day)
          : describeToday(day),
      maxLines: 1,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
