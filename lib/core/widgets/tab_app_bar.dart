// SPDX-License-Identifier: GPL-3.0-or-later

/// The top bar of the Habits, Food, Exercise and Sleep tabs.
library;

import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'day_bar.dart';

/// Narrower than this (in logical pixels), the date is written short.
const double _narrowWidth = 400;

/// How tall the row with the date and the day bar is.
const double _dayRowHeight = 48;

/// A tab's top bar: the tab's name and its buttons, as a plain [AppBar]
/// in the theme's colours. Only Home has the landscape; the tabs stay
/// plain, so their content leads.
///
/// For a tab about one day, a row under the title has the date and the
/// day bar, as on Home.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the bar.
  const TabAppBar({
    super.key,
    required this.title,
    this.actions,
    this.day,
    this.onDayChanged,
  });

  /// The tab's name.
  final Widget title;

  /// Buttons on the right.
  final List<Widget>? actions;

  /// The day the screen shows, for a screen about one day: then a row
  /// under the title has the date and the day bar. Null for none.
  final DateTime? day;

  /// Called with a newly chosen day, from the day bar.
  final ValueChanged<DateTime>? onDayChanged;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (day == null ? 0 : _dayRowHeight));

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    return AppBar(
      title: title,
      actions: actions,
      // The date and the day bar on their own row, so the title keeps its
      // room, even with large text.
      bottom: day == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(_dayRowHeight),
              child: SizedBox(
                height: _dayRowHeight,
                child: DayRow(day: day, onChanged: onDayChanged!),
              ),
            ),
    );
  }
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
              child: Text(
                // On a narrow phone the short form, "Sat 21 Nov", so the
                // date keeps its size beside the day bar.
                MediaQuery.sizeOf(context).width < _narrowWidth
                    ? formatShortDate(day)
                    : describeToday(day),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          DayBar(day: day, onChanged: onChanged),
        ],
      ),
    );
  }
}
