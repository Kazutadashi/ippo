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
import '../food_actions.dart';
import '../food_diary.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'choose_food_screen.dart';
import 'food_entry_form_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food'),
        actions: [DayBar(day: shownDay, onChanged: showDay)],
      ),
      // Adding to the whole day: buttons at the bottom right, as on the
      // other screens. Each needs its own hero tag, because Flutter
      // animates floating buttons between screens by this tag.
      // IntrinsicWidth with "stretch" gives both buttons the width of the
      // wider one, so they line up.
      floatingActionButton: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The quieter of the two: one accent-filled button is
            // enough, and Add food is the usual way.
            FloatingActionButton.extended(
              heroTag: 'quick-food',
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.primary,
              onPressed: _addQuickFood,
              icon: const Icon(Icons.bolt),
              label: const Text('Quick food'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'add-food',
              onPressed: _addEntry,
              icon: const Icon(Icons.add),
              label: const Text('Add food'),
            ),
          ],
        ),
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
            return ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),

              // Room at the bottom, so the buttons never hide an entry.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
              children: [
                if (diary.invalidCount > 0)
                  ProblemText(
                    '${diary.invalidCount} foods or entries in the data '
                    'could not be read and are not shown.',
                  ),
                SectionCard(
                  children: [
                    const CardHeader(
                      icon: Icons.local_fire_department,
                      title: 'Total',
                    ),
                    const SizedBox(height: 8),
                    NutrientInfoRow(nutrients: diary.totalOn(date)),
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
                    for (final entry in entries)
                      Dismissible(
                        key: ValueKey(entry.id),
                        direction: DismissDirection.endToStart,
                        background: const _RemoveBackground(),
                        // Removes the entry first, and lets the row go
                        // only once that is saved.
                        confirmDismiss: (_) => _removeEntry(entry),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.name),
                          subtitle: _EntryDetails(entry: entry),
                          trailing: Text(
                            formatEnergy(entry.nutrients.energyKcal),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          onTap: () => _editEntry(entry),
                        ),
                      ),
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
