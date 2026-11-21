// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module's main screen: what was eaten on one day.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/follows_today.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/sky_band.dart';
import '../food_actions.dart';
import '../food_diary.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import '../../body/body_log.dart';
import '../../body/screens/body_screen.dart';
import '../../body/screens/weight_card.dart';
import '../daily_references.dart';
import 'nutrient_bars.dart';
import 'choose_food_screen.dart';
import 'food_entry_form_screen.dart';
import 'foods_screen.dart';
import 'nutrient_summary.dart';
import 'quick_entry_form_screen.dart';

/// Shows one day's total, then everything eaten that day in the order
/// it was logged.
class FoodDiaryScreen extends StatefulWidget {
  /// Creates the diary screen.
  const FoodDiaryScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> with FollowsToday {
  @override
  AppState get dayState => widget.appState;

  void _addEntry() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChooseFoodScreen(
          appState: widget.appState,
          date: formatDate(shownDay),
          isToday: showsToday,
        ),
      ),
    );
  }

  void _addQuickFood() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => QuickEntryFormScreen.add(
          appState: widget.appState,
          date: formatDate(shownDay),
          isToday: showsToday,
        ),
      ),
    );
  }

  void _editEntry(FoodEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => entry.isQuickEntry
            ? QuickEntryFormScreen.edit(appState: widget.appState, entry: entry)
            : FoodEntryFormScreen.edit(appState: widget.appState, entry: entry),
      ),
    );
  }

  /// Removes [entry] after a swipe, and offers to undo it. Returns
  /// whether it was removed, so the row only slides away if it was.
  Future<bool> _removeEntry(FoodEntry entry) async {
    final actions = FoodActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final removed = await saveOrShowError(
      context,
      () => actions.deleteEntry(entry.id),
    );
    if (removed) {
      showUndoMessage(
        messenger,
        message: 'Removed ${entry.name}',
        onUndo: () => actions.restoreEntry(entry.id),
      );
    }
    return removed;
  }

  void _openBody() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BodyScreen(appState: widget.appState),
      ),
    );
  }

  /// One meal's row: tap it to change it, or swipe it left to remove
  /// it. The food's name stands out; its time and amount are smaller and
  /// grey under it; its energy sits on the right, in one column, so it is
  /// easy to scan.
  Widget _entryRow(FoodEntry entry) {
    final textTheme = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const _RemoveBackground(),
      // Removes the entry first, and lets the row go only once that is
      // saved.
      confirmDismiss: (_) => _removeEntry(entry),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(entry.name, style: textTheme.titleMedium),
        subtitle: DefaultTextStyle.merge(
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: _EntryDetails(entry: entry),
        ),
        trailing: Text(
          formatEnergy(entry.nutrients.energyKcal),
          style: textTheme.titleSmall,
        ),
        onTap: () => _editEntry(entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SkyAppBar(
        title: const Text('Food'),
        actions: [
          // Every saved food, to look over and change.
          IconButton(
            tooltip: 'Your foods',
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => FoodsScreen(appState: widget.appState),
              ),
            ),
          ),
          DayBar(day: shownDay, onChanged: showDay),
        ],
      ),
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: widget.appState.reloadEvents,
        child: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final diary = FoodDiary.of(widget.appState);
            final date = formatDate(shownDay);
            final entries = diary.entriesOn(date);
            final lastMeal = latestTimedEntry(entries);
            final body = BodyLog.of(widget.appState);
            final references = dailyReferencesOn(body, date);
            final energyTarget = body.energyTargetOn(date);
            return ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (diary.invalidCount > 0)
                  ProblemText(
                    '${diary.invalidCount} foods or entries in the data '
                    'could not be read and are not shown.',
                  ),
                SectionCard(
                  children: [
                    CardHeader(
                      icon: Icons.local_fire_department,
                      title: 'Total',
                      // Body details and the daily limit.
                      action: TextButton.icon(
                        onPressed: _openBody,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          energyTarget == null
                              ? 'Set daily limit'
                              : 'Daily limit',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    NutrientInfoRow(
                      nutrients: diary.totalOn(date),
                      references: references,
                      energyTarget: energyTarget,
                    ),
                    // With a limit: how much is left, or how far over.
                    if (energyTarget != null) ...[
                      const SizedBox(height: Spacing.small),
                      ShareBar(
                        share: diary.totalOn(date).energyKcal / energyTarget,
                        height: 6,
                      ),
                      const SizedBox(height: Spacing.tight),
                      NoteText(
                        _leftOrOver(
                          energyTarget - diary.totalOn(date).energyKcal,
                        ),
                      ),
                    ],
                    // When the last meal was, as on Home.
                    // Every other nutrient, folded away until asked for.
                    Theme(
                      // No lines above and below the opened list.
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'All nutrients',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        children: [
                          AllNutrientsList(
                            nutrients: diary.totalOn(date),
                            references: references,
                          ),
                        ],
                      ),
                    ),
                    if (lastMeal != null) ...[
                      const Divider(height: Spacing.screen),
                      _LastMealLine(
                        entry: lastMeal,
                        day: shownDay,
                        isToday: showsToday,
                      ),
                    ],
                  ],
                ),
                // The day's weight, typed in right here: the Food tab is
                // opened every day, so the weight is not forgotten.
                WeightCard(
                  key: ValueKey('weight $date'),
                  appState: widget.appState,
                  log: body,
                  date: date,
                  isCompact: true,
                ),
                // Adding to the day, just above what was eaten: Quick food
                // (a name and numbers) and Add food (from your foods),
                // side by side, the usual one filled.
                const SizedBox(height: Spacing.small),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addQuickFood,
                        icon: const Icon(Icons.bolt),
                        label: const Text('Quick food'),
                      ),
                    ),
                    const SizedBox(width: Spacing.small),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _addEntry,
                        icon: const Icon(Icons.add),
                        label: const Text('Add food'),
                      ),
                    ),
                  ],
                ),
                SectionCard(
                  children: [
                    const CardHeader(icon: Icons.restaurant, title: 'Eaten'),
                    // Says how to change or remove a meal, which is
                    // otherwise hidden. At the top, where the buttons
                    // never cover it.
                    if (entries.isNotEmpty)
                      const NoteText(
                        'Tap a meal to change it, or swipe it left to '
                        'remove it.',
                      ),
                    if (entries.isEmpty)
                      const NoteText('Nothing logged on this day.'),
                    // Tap a row to change it, or swipe it away to remove
                    // it. The energy sits on the right, in one column, so
                    // it is easy to scan.
                    for (final (index, entry) in newestFirst(
                      entries,
                    ).indexed) ...[
                      // A thin line between meals, so each stands apart.
                      if (index > 0) const Divider(height: 1),
                      _entryRow(entry),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "733 kcal left" or "120 kcal over", for [left] kilocalories left.
String _leftOrOver(double left) => left >= 0
    ? '${formatEnergy(left)} left'
    : '${formatEnergy(-left)} over the limit';

/// The last meal's time, and on the day itself how long ago that was:
/// "Last meal" on the left, "7:15 pm" and "8 h ago" on the right.
class _LastMealLine extends StatelessWidget {
  const _LastMealLine({
    required this.entry,
    required this.day,
    required this.isToday,
  });

  final FoodEntry entry;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final time = entry.time!;
    final eatenAt = momentOnDay(day, time);
    final elapsed = eatenAt == null ? null : DateTime.now().difference(eatenAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Last meal', style: textTheme.bodyMedium?.copyWith(color: muted)),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            entry.name,
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Text(showSavedTime(time), style: textTheme.titleSmall),
        if (isToday && elapsed != null && !elapsed.isNegative) ...[
          const SizedBox(width: Spacing.small),
          Text(
            formatTimeAgo(elapsed),
            style: textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}

/// What shows behind a meal while it is swiped away: a bin on red, the
/// theme's colour for deleting.
class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Spacing.screen),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
    );
  }
}

/// An entry's time and amount, side by side: "07:30   9 chips (28 g)".
/// The time is left out when it is not known.
class _EntryDetails extends StatelessWidget {
  const _EntryDetails({required this.entry});

  final FoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final time = entry.time;
    return Row(
      children: [
        if (time != null) ...[
          Text(showSavedTime(time)),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(_describeAmount(entry), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// The amount eaten, in pieces and grams if typed in pieces.
String _describeAmount(FoodEntry entry) {
  final amount = entry.amount;
  if (amount == null) {
    return 'Quick entry';
  }
  final grams = '${formatAmount(amount)} ${entry.measuredIn ?? ''}'.trim();
  final pieces = entry.unitCount;
  final pieceName = entry.unitName;
  if (pieces == null || pieceName == null) {
    return grams;
  }
  return '${formatAmount(pieces)} $pieceName ($grams)';
}

/// [entries] with the newest meal on top: by the time eaten, latest
/// first; meals without a time after them, the last logged first.
List<FoodEntry> newestFirst(List<FoodEntry> entries) {
  final numbered = entries.indexed.toList()
    ..sort((a, b) {
      final aTime = a.$2.time;
      final bTime = b.$2.time;
      if (aTime != null && bTime != null && aTime != bTime) {
        return bTime.compareTo(aTime);
      }
      if ((aTime == null) != (bTime == null)) {
        // A meal with a time comes before one without.
        return aTime == null ? 1 : -1;
      }
      // Same time, or neither has one: the one logged later first.
      return b.$1.compareTo(a.$1);
    });
  return [for (final (_, entry) in numbered) entry];
}
