// SPDX-License-Identifier: GPL-3.0-or-later

/// Logging an amount of a food, or changing such an entry.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'meal_picker.dart';
import 'nutrient_summary.dart';

/// The form for an entry made from a food: amount and meal.
///
/// Closes with `true` when something was saved or deleted.
class FoodEntryFormScreen extends StatefulWidget {
  /// Creates the form for logging [food] on [date].
  const FoodEntryFormScreen.add({
    super.key,
    required this.appState,
    required Food this.food,
    required String this.date,
    required this.isToday,
    required Meal this.meal,
  }) : entry = null;

  /// Creates the form for changing [entry].
  const FoodEntryFormScreen.edit({
    super.key,
    required this.appState,
    required FoodEntry this.entry,
  }) : food = null,
       date = null,
       isToday = false,
       meal = null;

  /// The app-wide state.
  final AppState appState;

  /// The food to log, when adding.
  final Food? food;

  /// The day to log on (`YYYY-MM-DD`), when adding.
  final String? date;

  /// Whether [date] is today, so the entry gets the current time.
  final bool isToday;

  /// The meal to start with, when adding.
  final Meal? meal;

  /// The entry to change, when editing.
  final FoodEntry? entry;

  @override
  State<FoodEntryFormScreen> createState() => _FoodEntryFormScreenState();
}

class _FoodEntryFormScreenState extends State<FoodEntryFormScreen> {
  late final TextEditingController _amountField = TextEditingController(
    text: widget.entry?.amount == null
        ? ''
        : formatAmount(widget.entry!.amount!),
  );
  late Meal _meal =
      widget.meal ?? widget.entry?.meal ?? guessMeal(DateTime.now());
  String? _amountProblem;

  @override
  void dispose() {
    _amountField.dispose();
    super.dispose();
  }

  String get _name => widget.food?.name ?? widget.entry!.name;

  String get _unit => widget.food?.measuredIn ?? widget.entry!.measuredIn ?? '';

  /// The nutrients for [amount], for the live preview.
  Nutrients _nutrientsFor(double amount) {
    final food = widget.food;
    if (food != null) {
      return food.nutrientsFor(amount);
    }
    // Editing: scale the entry's own copy, as FoodActions will.
    final entry = widget.entry!;
    final oldAmount = entry.amount ?? 0;
    return oldAmount == 0
        ? entry.nutrients
        : entry.nutrients.scaledBy(amount / oldAmount);
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountField.text);
    if (amount == null || amount == 0) {
      setState(() => _amountProblem = 'Please enter an amount above 0.');
      return;
    }
    final actions = FoodActions(widget.appState);
    final food = widget.food;
    final entry = widget.entry;
    final saved = await saveOrShowError(context, () {
      if (food != null) {
        return actions.recordFoodEntry(
          date: widget.date!,
          time: widget.isToday ? formatTimeOfDay(DateTime.now()) : null,
          meal: _meal,
          food: food,
          amount: amount,
        );
      }
      return actions.changeFoodEntryAmount(
        entry!,
        newAmount: amount,
        meal: _meal,
      );
    });
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry!;
    final actions = FoodActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteEntry(entry.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    showUndoMessage(
      messenger,
      message: 'Deleted ${entry.name}.',
      onUndo: () => actions.restoreEntry(entry.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseAmount(_amountField.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(_name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amountField,
            autofocus: widget.entry == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _unit,
              errorText: _amountProblem,
            ),
            // Redraw so the preview below follows the typed amount.
            onChanged: (_) => setState(() => _amountProblem = null),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          MealPicker(
            selected: _meal,
            onChanged: (meal) => setState(() => _meal = meal),
          ),
          const SizedBox(height: 16),
          NutrientInfoRow(nutrients: _nutrientsFor(amount)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (widget.entry != null)
            DeleteButton(label: 'Delete this entry', onPressed: _delete),
        ],
      ),
    );
  }
}
