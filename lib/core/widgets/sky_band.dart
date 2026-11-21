// SPDX-License-Identifier: GPL-3.0-or-later

/// The top bar of the Habits, Food, Exercise and Sleep tabs, on the
/// Home sky.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'day_bar.dart';
import 'sky_header.dart';

/// How tall the fade into the page is, under everything else.
const double _extraHeight = 20;

/// How tall the row with the date and the day bar is.
const double _dayRowHeight = 48;

/// A tab's top bar on the sky of the top of Home: the same colours for
/// the hour, with its birds by day, or its stars and shooting star at
/// dusk and night; no sun, moon or mountains, which stay Home's. It
/// fades into the page below the title. The title and buttons
/// are white on it, whatever the theme.
///
/// It is a plain [AppBar] otherwise, with the same [title] and
/// [actions].
class SkyAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the bar.
  const SkyAppBar({
    super.key,
    required this.title,
    this.actions,
    this.phase,
    this.day,
    this.onDayChanged,
  });

  /// The tab's name.
  final Widget title;

  /// Buttons on the right, such as the day picker.
  final List<Widget>? actions;

  /// The sky to draw, or null for the sky at this hour (always, in the
  /// app; tests set it to look at each sky).
  final SkyPhase? phase;

  /// The day the screen shows, for a screen about one day: then a row
  /// under the title has the date and the day bar, as on Home. Null for
  /// none.
  final DateTime? day;

  /// Called with a newly chosen day, from the day bar.
  final ValueChanged<DateTime>? onDayChanged;

  /// How tall the part under the title is: the day row, if any, and the
  /// fade.
  double get _bottomHeight => (day == null ? 0 : _dayRowHeight) + _extraHeight;

  @override
  Size get preferredSize => Size.fromHeight(52 + _bottomHeight);

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).colorScheme.surface;
    final topInset = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    return AppBar(
      title: title,
      actions: actions,
      // White on the sky; white icons in the phone's status bar too.
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Under the title: the date and the day bar, on their own row so
      // the title keeps its room, even with large text; then the fade.
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_bottomHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (day != null)
              SizedBox(
                height: _dayRowHeight,
                child: _DayRow(day: day!, onChanged: onDayChanged!),
              ),
            const SizedBox(height: _extraHeight),
          ],
        ),
      ),
      flexibleSpace: ExcludeSemantics(
        child: ClipRect(
          child: Stack(
            children: [
              // Home's sky, at Home's size and place, so its stars and
              // birds sit where they do on Home; the bar shows its top.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SkyHeader(
                  phase: phase ?? SkyPhase.of(now),
                  height: topInset + 156,
                  clearTop: topInset + 44,
                  seed: SkyHeader.seedFor(currentDay(now)),
                  skyOnly: true,
                ),
              ),
              // Fading into the page at the very bottom, under the title
              // and the day row, so the cut is never a hard edge and the
              // white text always sits on sky.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _extraHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [page.withValues(alpha: 0), page],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row under a tab's title: the date on the left, as on Home, and the
/// day bar on the right; white, like the title, on the sky.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconTheme.merge(
      data: const IconThemeData(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            // One line: a long date shrinks a little rather than wrap.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  describeToday(day),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: Colors.white),
                ),
              ),
            ),
            DayBar(day: day, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
