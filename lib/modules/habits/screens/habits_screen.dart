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
import '../habit.dart';
import '../habit_actions.dart';
import '../habit_log.dart';
import 'habit_form_screen.dart';

/// How many days the grid shows; scroll sideways to see further back.
const int _shownDays = 60;

/// The width of one past day's column. Narrow, so more days fit.
const double _dayWidth = 34;

/// Today's column is wider: it is the one tapped every day, and the
/// extra width keeps it apart from yesterday, so mis-taps are rarer.
const double _todayWidth = 40;

/// The height of one habit's row. Compact on purpose, so many habits
/// fit on one screen; under the usual 48 tap target, but a whole row of
/// a column is easy to hit.
const double _rowHeight = 36;

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
  AppState get appState => widget.appState;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      floatingActionButton: FloatingActionButton.extended(
        // Every floating button needs its own tag: all tabs stay alive at
        // once, and Flutter cannot animate two buttons with one tag.
        heroTag: 'new-habit',
        onPressed: () => _open(context, HabitFormScreen(appState: appState)),
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: appState.reloadEvents,
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final log = HabitLog.of(appState);
            final habits = log.shownHabits;
            return ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),

              // Room at the bottom, so the button never hides a habit.
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
              children: [
                if (log.invalidCount > 0)
                  ProblemText(
                    '${log.invalidCount} items in the data could not be read '
                    'and are not shown.',
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: nameWidth,
              child: Column(
                children: [
                  const SizedBox(height: _headerHeight),
                  for (final habit in habits)
                    _HabitName(habit: habit, onTap: () => onEditHabit(habit)),
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
                          _DayHeader(day: day, isToday: day == todayDate),
                      ],
                    ),
                    for (final habit in habits)
                      Row(
                        children: [
                          for (final day in days)
                            _DayCell(
                              appState: appState,
                              log: log,
                              habit: habit,
                              day: day,
                              isToday: day == todayDate,
                            ),
                        ],
                      ),
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
                  color: habit.displayColor(Theme.of(context)),
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
  const _DayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = isToday ? colors.primary : colors.onSurfaceVariant;
    return Container(
      width: isToday ? _todayWidth : _dayWidth,
      height: _headerHeight,
      color: isToday ? colors.primary.withValues(alpha: 0.08) : null,
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
    );
  }
}

/// One habit on one day: ✓, ✗, or a dot for nothing recorded. Tapping
/// moves it on: nothing → ✓ → ✗ → nothing.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.appState,
    required this.log,
    required this.habit,
    required this.day,
    required this.isToday,
  });

  final AppState appState;
  final HabitLog log;
  final Habit habit;
  final DateTime day;

  /// Today's column has a soft tint, so it stands out.
  final bool isToday;

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
        icon = Icon(
          Icons.check,
          size: _markSize,
          color: habit.displayColor(theme),
        );
        meaning = 'done';
      case DayMark.notDone:
        icon = Icon(
          Icons.close,
          size: _markSize,
          color: colors.onSurfaceVariant,
        );
        meaning = 'not done';
      case DayMark.none:
        icon = Icon(Icons.circle, size: 5, color: colors.outlineVariant);
        meaning = 'not recorded';
    }
    return Semantics(
      label: '${habit.name}, ${formatShortDate(day)}: $meaning',
      button: true,
      child: Material(
        color: isToday
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
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
            width: isToday ? _todayWidth : _dayWidth,
            height: _rowHeight,
            // The new mark grows in, so the change is easy to see.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Center(key: ValueKey(mark), child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
