// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module's main screen: what was eaten on one day.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../food_diary.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'choose_food_screen.dart';
import 'food_entry_form_screen.dart';
import 'nutrient_summary.dart';
import 'quick_entry_form_screen.dart';

/// The icon shown for each meal.
const Map<Meal, IconData> _mealIcons = {
  Meal.breakfast: Icons.free_breakfast,
  Meal.lunch: Icons.lunch_dining,
  Meal.dinner: Icons.dinner_dining,
  Meal.snack: Icons.cookie,
};

/// Shows one day's total, then one card per meal with its entries and
/// an Add button.
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
  DateTime _day = today();

  void _addEntry(Meal meal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChooseFoodScreen(
          appState: widget.appState,
          date: formatDate(_day),
          isToday: _day == today(),
          meal: meal,
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
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final events = widget.appState.eventLog?.events ?? [];
          final diary = FoodDiary.fromEvents(events);
          final date = formatDate(_day);
          final entries = diary.entriesOn(date);
          final entriesWithoutMeal = entries
              .where((entry) => entry.meal == null)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DayBar(day: _day, onChanged: (day) => setState(() => _day = day)),
              if (diary.invalidCount > 0)
                ProblemText(
                  '${diary.invalidCount} foods or entries in the data '
                  'could not be read and are not shown.',
                ),
              SectionCard(
                children: [
                  const CardHeader(icon: Icons.restaurant, title: 'Total'),
                  const SizedBox(height: 8),
                  NutrientInfoRow(nutrients: diary.totalOn(date)),
                ],
              ),
              for (final meal in Meal.values)
                _MealCard(
                  icon: _mealIcons[meal]!,
                  title: meal.label,
                  entries: entries.where((entry) => entry.meal == meal),
                  onAdd: () => _addEntry(meal),
                  onEdit: _editEntry,
                ),
              // Entries without a meal can only come from other tools.
              if (entriesWithoutMeal.isNotEmpty)
                _MealCard(
                  icon: Icons.restaurant_menu,
                  title: 'Other',
                  entries: entriesWithoutMeal,
                  onAdd: null,
                  onEdit: _editEntry,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One meal's card: its name and energy, its entries, and an Add button.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.icon,
    required this.title,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final Iterable<FoodEntry> entries;
  final VoidCallback? onAdd;
  final ValueChanged<FoodEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    var total = Nutrients.none;
    for (final entry in entries) {
      total = total.plus(entry.nutrients);
    }
    final onAdd = this.onAdd;
    return SectionCard(
      children: [
        CardHeader(
          icon: icon,
          title: entries.isEmpty
              ? title
              : '$title · ${formatAmount(total.energyKcal)} kcal',
          action: onAdd == null ? null : HeaderAddButton(onPressed: onAdd),
        ),
        if (entries.isEmpty) const NoteText('Nothing logged.'),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.name),
            subtitle: Text(_describeEntry(entry)),
            trailing: IconButton(
              tooltip: 'Edit entry',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onEdit(entry),
            ),
            onTap: () => onEdit(entry),
          ),
      ],
    );
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
