// SPDX-License-Identifier: GPL-3.0-or-later

/// Choosing what to log: a food from the list, or a new food for the
/// list. (Quick entries have their own button on the diary.)
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_diary.dart';
import 'food_entry_form_screen.dart';
import 'food_form_screen.dart';

/// Lists the user's foods, most recently used first, with a search box.
class ChooseFoodScreen extends StatefulWidget {
  /// Creates the screen for logging on [date] (`YYYY-MM-DD`).
  /// [isToday] decides whether the entry gets the current time.
  const ChooseFoodScreen({
    super.key,
    required this.appState,
    required this.date,
    required this.isToday,
  });

  /// The app-wide state.
  final AppState appState;

  /// The day to log on.
  final String date;

  /// Whether [date] is today.
  final bool isToday;

  @override
  State<ChooseFoodScreen> createState() => _ChooseFoodScreenState();
}

class _ChooseFoodScreenState extends State<ChooseFoodScreen> {
  String _search = '';

  /// Opens the next screen. If it reports that an entry was saved, this
  /// screen closes too, going straight back to the diary.
  Future<void> _openAndCloseIfSaved(Widget screen) async {
    final saved = await Navigator.of(context)
        .push(MaterialPageRoute<bool>(builder: (context) => screen));
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _logFood(Food food) {
    _openAndCloseIfSaved(
      FoodEntryFormScreen.add(
        appState: widget.appState,
        food: food,
        date: widget.date,
        isToday: widget.isToday,
      ),
    );
  }

  Future<void> _newFood() async {
    final newFoodId = await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (context) => FoodFormScreen.add(appState: widget.appState),
      ),
    );
    if (newFoodId == null || !mounted) {
      return;
    }
    // Go straight on to logging the new food.
    final events = widget.appState.eventLog?.events ?? [];
    final newFood = FoodDiary.fromEvents(events).foods[newFoodId];
    if (newFood != null) {
      _logFood(newFood);
    }
  }

  void _editFood(Food food) {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (context) =>
            FoodFormScreen.edit(appState: widget.appState, food: food),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add food')),
      // Creating a food is for the whole screen, so it is a floating
      // button, as on the other screens.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-food',
        onPressed: _newFood,
        icon: const Icon(Icons.add),
        label: const Text('New food'),
      ),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final events = widget.appState.eventLog?.events ?? [];
          final foods = FoodDiary.fromEvents(events)
              .foodsByRecentUse()
              .where(
                (food) =>
                    food.name.toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();
          return ListView(
            // Room at the bottom, so the button never hides a food.
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              SectionCard(
                children: [
                  const CardHeader(icon: Icons.list_alt, title: 'Your foods'),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search your foods',
                    ),
                    onChanged: (text) => setState(() => _search = text),
                  ),
                  const SizedBox(height: 8),
                  if (foods.isEmpty)
                    const NoteText('No foods found. Tap New food to add one.'),
                  for (final food in foods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(food.name),
                      subtitle: Text(_describeFood(food)),
                      onTap: () => _logFood(food),
                      trailing: IconButton(
                        tooltip: 'Edit food',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editFood(food),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Describes a food for the list: energy per 100 g, and the serving size
/// if known, for example `536 kcal per 100 g · 9 chips (28 g)`.
String _describeFood(Food food) {
  final energy =
      '${formatAmount(food.nutrientsPer100.energyKcal)} kcal per 100 '
      '${food.measuredIn}';
  final serving = food.serving;
  return serving == null
      ? energy
      : '$energy · ${serving.describe(food.measuredIn)}';
}
