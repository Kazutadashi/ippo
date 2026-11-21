// SPDX-License-Identifier: GPL-3.0-or-later

/// Choosing what to log: a food from the list, or a new food for the
/// list. (Quick entries have their own button on the diary.)
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/events/event.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_diary.dart';
import '../food_serving.dart';
import '../nutrients.dart';
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

  /// Opens "New food", with [name] already typed, then logs the new food.
  /// Logs one serving of [food] straight away, with no form: the
  /// quickest way to log what you eat often. It is timed now (today), or
  /// left without a time (another day), as the form would start. Then
  /// back to the diary, with a message to undo it.
  Future<void> _logOneServing(Food food, FoodServing serving) async {
    final messenger = ScaffoldMessenger.of(context);
    final actions = FoodActions(widget.appState);
    Event? logged;
    final time = startingEntryTime(
      entryTime: null,
      isNew: true,
      isToday: widget.isToday,
    );
    final saved = await saveOrShowError(context, () async {
      logged = await actions.recordFoodEntry(
        date: widget.date,
        time: time?.toString(),
        food: food,
        amount: serving.amount,
        unitCount: serving.count,
        unitName: serving.unit,
      );
    });
    final event = logged;
    if (!saved || event == null || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Logged ${writeServingText(serving)} of ${food.name}.',
      onUndo: () => actions.deleteEntry(event.id),
    );
  }

  Future<void> _newFood({String name = ''}) async {
    final newFoodId = await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (context) =>
            FoodFormScreen.add(appState: widget.appState, initialName: name),
      ),
    );
    if (newFoodId == null || !mounted) {
      return;
    }
    // Go straight on to logging the new food.
    final newFood = FoodDiary.of(widget.appState).foods[newFoodId];
    if (newFood != null) {
      _logFood(newFood);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add food')),
      // Creating a food is for the whole screen, so it is a floating
      // button, as on the other screens.
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final foods = FoodDiary.of(widget.appState)
              .foodsByRecentUse()
              .where(
                (food) =>
                    food.name.toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();
          return ListView(
            padding: belowNavigationBar(
              context,
              const EdgeInsets.fromLTRB(16, 4, 16, 24),
            ),
            children: [
              // A new food: in the right half, where the tabs have their
              // add buttons.
              Row(
                children: [
                  const Spacer(),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _newFood(),
                      icon: const Icon(Icons.add),
                      label: const Text('New food'),
                    ),
                  ),
                ],
              ),
              SectionCard(
                children: [
                  const CardHeader(icon: Icons.list_alt, title: 'Your foods'),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search your foods',
                    ),
                    onChanged: (text) => setState(() => _search = text),
                  ),
                  const SizedBox(height: 8),
                  if (foods.isEmpty && _search.trim().isEmpty)
                    const NoteText('No foods yet. Tap New food to add one.'),
                  // Nothing found: offer to make it, with the name typed.
                  if (foods.isEmpty && _search.trim().isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add),
                      title: Text('Create "${_search.trim()}"'),
                      onTap: () => _newFood(name: _search.trim()),
                    ),
                  // Tap a food to log it. The food itself can be changed
                  // from the next screen.
                  // Tap a food to choose the amount; foods with a serving
                  // size also have a button that logs one serving at once.
                  for (final food in foods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(food.name),
                      subtitle: _servingText(food),
                      trailing: food.serving == null
                          ? _EnergyPer100(food: food)
                          : IconButton.filledTonal(
                              tooltip:
                                  'Log ${writeServingText(food.serving!)} now',
                              icon: const Icon(Icons.add),
                              onPressed: () =>
                                  _logOneServing(food, food.serving!),
                            ),
                      onTap: () => _logFood(food),
                    ),
                  if (foods.any((food) => food.serving != null))
                    const NoteText(
                      'Tap a food to choose the amount, or + to log one '
                      'serving now.',
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

/// A food's serving and what it comes to, such as "1 slice (36 g) ·
/// 89 kcal", or nothing for a food without a serving size.
Widget? _servingText(Food food) {
  final serving = food.serving;
  if (serving == null) {
    return null;
  }
  final energy = food.nutrientsFor(serving.amount).energyKcal;
  return Text('${serving.describe(food.measuredIn)} · ${formatEnergy(energy)}');
}

/// A food's energy per 100 g (or ml), on the right of its row: the
/// number above, what it is per below, so the column is easy to scan.
class _EnergyPer100 extends StatelessWidget {
  const _EnergyPer100({required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatEnergy(food.nutrientsPer100.energyKcal),
          style: textTheme.titleSmall,
        ),
        Text(
          'per 100 ${food.measuredIn}',
          style: textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
