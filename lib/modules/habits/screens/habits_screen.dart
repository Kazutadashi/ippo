// SPDX-License-Identifier: GPL-3.0-or-later

/// The habits module's main screen: a grid of habits (top to bottom) and
/// days (today on the left, the past to the right).
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/follows_today.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/sky_band.dart';
import '../habit.dart';
import '../habit_actions.dart';
import '../habit_log.dart';
import '../habit_marks.dart';
import 'habit_form_screen.dart';
import '../habit_order.dart';

/// How many days the grid shows; scroll sideways to see further back.
const int _shownDays = 60;

/// The narrowest a past day's column may be. Narrow, so more days fit;
/// the columns are then widened a little so whole days fill the card.
const double _minDayWidth = 34;

/// Today's column is wider: it is the one tapped every day, and the
/// extra width keeps it apart from yesterday, so mis-taps are rarer.
const double _todayWidth = 40;

/// The height of one habit's row. Compact on purpose, so many habits
/// fit on one screen, yet tall enough for a name on two lines. Under the
/// usual 48 tap target, but over WCAG's 24 (see "Accessibility" in
/// docs/design.md).
const double _rowHeight = 42;

/// How round the ends of today's column are.
const Radius _todayCorner = Radius.circular(10);

/// The height of the row of dates at the top.
const double _headerHeight = 34;

/// The size of the ✓ and ✗ marks.
const double _markSize = 18;

/// The habits grid. Tap a day to cycle it: nothing → ✓ → ✗ → nothing.
class HabitsScreen extends StatefulWidget {
  /// Creates the screen.
  const HabitsScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

// FollowsToday moves today's column on by itself after midnight.
class _HabitsScreenState extends State<HabitsScreen> with FollowsToday {
  @override
  AppState get dayState => widget.appState;

  AppState get appState => widget.appState;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SkyAppBar(
        title: const Text('Habits'),
        actions: [_OrderButton(appState: appState)],
      ),
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: appState.reloadEvents,
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final log = HabitLog.of(appState);
            final habits = habitsInOrder(appState, log);
            return ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                if (log.invalidCount > 0)
                  ProblemText(
                    '${log.invalidCount} items in the data could not be read '
                    'and are not shown.',
                  ),
                // A new habit, just above the habits: in the right half,
                // where Add food and New exercise are on their tabs.
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.tight),
                  child: Row(
                    children: [
                      const Spacer(),
                      const SizedBox(width: Spacing.small),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _open(
                            context,
                            HabitFormScreen(appState: appState),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('New habit'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (habits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Spacing.screen),
                    child: NoteText(
                      'Tap "New habit" to add one. Then tap a day to mark it '
                      'done (✓) or not done (✗).',
                    ),
                  )
                else
                  Card(
                    margin: const EdgeInsets.only(top: Spacing.tight),
                    clipBehavior: Clip.antiAlias,
                    // Room above the dates and below the last habit, so
                    // today's column ends inside the card, not at its edge.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.small,
                      ),
                      child: _HabitGrid(
                        today: today(),
                        appState: appState,
                        log: log,
                        habits: habits,
                        onEditHabit: (habit) => _open(
                          context,
                          HabitFormScreen(appState: appState, habit: habit),
                        ),
                      ),
                    ),
                  ),
                if (habits.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Spacing.small),
                    child: NoteText(
                      'Tap a day to mark it done (✓), again for not done (✗). '
                      'Tap a name to change the habit.',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The grid: habit names in a fixed column on the left, and the days in
/// a sideways-scrolling area, today first.
class _HabitGrid extends StatelessWidget {
  const _HabitGrid({
    required this.today,
    required this.appState,
    required this.log,
    required this.habits,
    required this.onEditHabit,
  });

  final DateTime today;
  final AppState appState;
  final HabitLog log;
  final List<Habit> habits;
  final ValueChanged<Habit> onEditHabit;

  @override
  Widget build(BuildContext context) {
    final todayDate = today;
    final days = [
      for (var back = 0; back < _shownDays; back++) addDays(todayDate, -back),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Names get just over a quarter of the width, so most of it
        // shows days; long names wrap onto a second line.
        final nameWidth = (constraints.maxWidth * 0.27).clamp(80.0, 150.0);
        // As many whole past days as fit beside today, widened to fill
        // the card exactly, so no column is cut in half at the edge.
        final pastWidth = constraints.maxWidth - nameWidth - _todayWidth;
        final pastShown = (pastWidth / _minDayWidth).floor();
        final dayWidth = pastShown > 0 ? pastWidth / pastShown : _minDayWidth;
        final lastHabit = habits.last;
        // The whole width of the days, for the lines between habits.
        final allDaysWidth = _todayWidth + dayWidth * (days.length - 1);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: nameWidth,
              child: Column(
                children: [
                  const SizedBox(height: _headerHeight),
                  for (final habit in habits) ...[
                    _HabitName(habit: habit, onTap: () => onEditHabit(habit)),
                    if (habit != lastHabit)
                      const _RowLine(width: double.infinity, indent: 10),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final day in days)
                          _DayHeader(
                            day: day,
                            isToday: day == todayDate,
                            width: day == todayDate ? _todayWidth : dayWidth,
                          ),
                      ],
                    ),
                    for (final habit in habits) ...[
                      Row(
                        children: [
                          for (final day in days)
                            _DayCell(
                              appState: appState,
                              log: log,
                              habit: habit,
                              day: day,
                              isToday: day == todayDate,
                              isLastRow: habit == lastHabit,
                              width: day == todayDate ? _todayWidth : dayWidth,
                            ),
                        ],
                      ),
                      if (habit != lastHabit) _RowLine(width: allDaysWidth),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A faint line between two habits, so the eye can follow a row across
/// the days. [indent] leaves room on the left, under the names.
class _RowLine extends StatelessWidget {
  const _RowLine({required this.width, this.indent = 0});

  /// How long the line is: a scrolling row has no width of its own.
  final double width;

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 1,
      margin: EdgeInsets.only(left: indent),
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.35),
    );
  }
}

/// A habit's name; tap it to rename or delete the habit.
class _HabitName extends StatelessWidget {
  const _HabitName({required this.habit, required this.onTap});

  final Habit habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Edit habit',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _rowHeight,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, Spacing.tight, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                habit.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: habit.textColor(Theme.of(context)),
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A day at the top of a column: weekday and day of the month, with
/// today in the accent colour.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.width,
  });

  final DateTime day;
  final bool isToday;

  /// The column's width.
  final double width;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = isToday ? colors.primary : colors.onSurfaceVariant;
    return Container(
      width: width,
      height: _headerHeight,
      // Today's column is a soft band with a rounded top.
      decoration: BoxDecoration(
        color: isToday ? colors.primary.withValues(alpha: 0.08) : null,
        borderRadius: const BorderRadius.vertical(top: _todayCorner),
      ),
      // With large text, the day and date shrink to fit the header,
      // instead of spilling out of it.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // One line each, whatever the font, so the header keeps its
            // height.
            Text(
              weekdays[day.weekday - 1],
              style: textTheme.labelSmall?.copyWith(color: color),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
            Text(
              '${day.day}',
              style: textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ],
        ),
      ),
    );
  }
}

/// One habit on one day: ✓, ✗, or nothing recorded (an empty ring
/// today, a dot before). Tapping
/// moves it on: nothing → ✓ → ✗ → nothing.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.appState,
    required this.log,
    required this.habit,
    required this.day,
    required this.isToday,
    required this.isLastRow,
    required this.width,
  });

  final AppState appState;
  final HabitLog log;
  final Habit habit;
  final DateTime day;

  /// Today's column has a soft tint, so it stands out.
  final bool isToday;

  /// Whether this is the bottom habit, where today's band gets its
  /// rounded end.
  final bool isLastRow;

  /// The column's width.
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = formatDate(day);
    final mark = log.markOn(habit.id, date);
    final Widget icon;
    final String meaning;
    switch (mark) {
      case DayMark.done:
        icon = BoldCheck(size: _markSize, color: habit.displayColor(theme));
        meaning = 'done';
      case DayMark.notDone when log.isCoveredOn(habit, date):
        // Not done, but the habit was done often enough around it ("twice
        // a week" kept): a faded ✓, so it does not look missed.
        icon = CoveredCheck(size: _markSize, color: habit.displayColor(theme));
        meaning = 'not done, but covered';
      case DayMark.notDone:
        // Quieter than a ✓: a "no" is information, not an alarm.
        icon = Icon(
          Icons.close,
          size: _markSize,
          color: colors.onSurfaceVariant.withValues(alpha: 0.45),
        );
        meaning = 'not done';
      case DayMark.none when !log.isDueOn(habit, date):
        // Not due (a habit for some days only, waiting for its next
        // turn): a short dash, so a waiting day never looks missed.
        icon = Container(
          width: 10,
          height: 2,
          color: habit.displayColor(theme).withValues(alpha: 0.5),
        );
        meaning = 'not due';
      case DayMark.none:
        // Today, an empty ring in the habit's colour: a box waiting to be
        // ticked. Past days, only a quiet dot, so the grid stays calm.
        icon = isToday
            ? Icon(
                Icons.circle_outlined,
                size: _markSize * 0.8,
                color: habit.displayColor(theme).withValues(alpha: 0.7),
              )
            : Icon(Icons.circle, size: 5, color: colors.outlineVariant);
        meaning = 'not recorded';
    }
    return Semantics(
      label: '${habit.name}, ${formatShortDate(day)}: $meaning',
      button: true,
      child: Material(
        color: isToday
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: isLastRow
            ? const BorderRadius.vertical(bottom: _todayCorner)
            : null,
        child: InkWell(
          onTap: () {
            // A light tick confirms the tap at once, before saving.
            HapticFeedback.selectionClick();
            saveOrShowError(
              context,
              () => HabitActions(appState).cycleDay(habit.id, date, log),
            );
          },
          child: SizedBox(
            width: width,
            height: _rowHeight,
            // The new mark grows in, so the change is easy to see.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Center(key: ValueKey('$mark $meaning'), child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top bar's button for the order of the habits: as added, or by
/// colour (similar colours together). The choice is saved, and Home's
/// tile follows it.
class _OrderButton extends StatelessWidget {
  const _OrderButton({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final byColour = appState.settings?.sortsHabitsByColour ?? false;
    return PopupMenuButton<String>(
      tooltip: 'Order of the habits',
      icon: const Icon(Icons.sort),
      onSelected: appState.setHabitOrder,
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'added',
          checked: !byColour,
          child: const Text('As added'),
        ),
        CheckedPopupMenuItem(
          value: 'colour',
          checked: byColour,
          child: const Text('By colour'),
        ),
      ],
    );
  }
}
