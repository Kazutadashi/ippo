// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module's main screen: what was eaten on one day.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../food_diary.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'choose_food_screen.dart';
import 'food_entry_form_screen.dart';
import 'nutrient_summary.dart';
import 'quick_entry_form_screen.dart';

/// Shows one day's food entries, grouped by meal, with the day's total.
class FoodDiaryScreen extends StatefulWidget {
  /// Creates the diary screen.
  const FoodDiaryScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> {
  /// The day being shown, at local midnight. Starts at today.
  DateTime _day = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _changeDay(int days) => setState(() => _day = addDays(_day, days));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: addDays(_today(), 365),
    );
    if (picked != null) {
      setState(() => _day = picked);
    }
  }

  void _addEntry() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChooseFoodScreen(
          appState: widget.appState,
          date: formatDate(_day),
          isToday: _day == _today(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final events = widget.appState.eventLog?.events ?? [];
          final diary = FoodDiary.fromEvents(events);
          final date = formatDate(_day);
          final entries = diary.entriesOn(date);
          return ListView(
            // Leave room at the bottom so the button never hides an entry.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _buildDayBar(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: NutrientSummary(nutrients: diary.totalOn(date)),
                ),
              ),
              if (diary.invalidCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${diary.invalidCount} foods or entries in the data '
                    'could not be read and are not shown.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Nothing logged on this day yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final meal in [...Meal.values, null])
                ..._buildMealSection(meal, entries),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeDay(-1),
        ),
        Expanded(
          child: TextButton(
            onPressed: _pickDay,
            child: Text(_describeDay(_day)),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeDay(1),
        ),
      ],
    );
  }

  /// The entries of one meal, with a heading. [meal] null means entries
  /// without a meal (possible in data from other tools).
  List<Widget> _buildMealSection(Meal? meal, List<FoodEntry> dayEntries) {
    final entries = dayEntries.where((entry) => entry.meal == meal).toList();
    if (entries.isEmpty) {
      return [];
    }
    var mealTotal = Nutrients.none;
    for (final entry in entries) {
      mealTotal = mealTotal.plus(entry.nutrients);
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          '${meal?.label ?? 'Other'} · '
          '${formatAmount(mealTotal.energyKcal)} kcal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final entry in entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.name),
          subtitle: Text(_describeEntry(entry)),
          onTap: () => _editEntry(entry),
        ),
    ];
  }
}

/// Describes an entry's amount and energy, for example
/// `150 g · 280 kcal` or `Quick entry · 850 kcal`.
String _describeEntry(FoodEntry entry) {
  final energy = '${formatAmount(entry.nutrients.energyKcal)} kcal';
  final amount = entry.amount;
  if (amount == null) {
    return 'Quick entry · $energy';
  }
  return '${formatAmount(amount)} ${entry.measuredIn ?? ''} · $energy';
}

/// Names a day: `Today`, `Yesterday`, `Tomorrow`, or for example
/// `Mon 2026-11-16`.
String _describeDay(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    return 'Today';
  }
  if (day == addDays(today, -1)) {
    return 'Yesterday';
  }
  if (day == addDays(today, 1)) {
    return 'Tomorrow';
  }
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[day.weekday - 1]} ${formatDate(day)}';
}
