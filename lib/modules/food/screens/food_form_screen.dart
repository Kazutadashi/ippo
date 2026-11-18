// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding a food to the food list, or changing one.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_actions.dart';
import '../nutrients.dart';

/// The form for a food: name, unit, and nutrients per 100 g or ml.
///
/// When adding, closes with the new food's id.
class FoodFormScreen extends StatefulWidget {
  /// Creates the form for a new food.
  const FoodFormScreen.add({super.key, required this.appState}) : food = null;

  /// Creates the form for changing [food].
  const FoodFormScreen.edit({
    super.key,
    required this.appState,
    required Food this.food,
  });

  /// The app-wide state.
  final AppState appState;

  /// The food to change, when editing.
  final Food? food;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.food?.name ?? '',
  );
  late final Map<String, TextEditingController> _nutrientFields = {
    for (final kind in allNutrientKinds)
      kind.key: TextEditingController(
        text: widget.food?.nutrientsPer100.values[kind.key] == null
            ? ''
            : formatAmount(widget.food!.nutrientsPer100.values[kind.key]!),
      ),
  };
  late String _unit = widget.food?.measuredIn ?? 'g';
  String? _nameProblem;
  final Map<String, String> _nutrientProblems = {};

  @override
  void dispose() {
    _nameField.dispose();
    for (final field in _nutrientFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// Reads the typed nutrients and notes any problems. Returns null if
  /// there is a problem.
  Nutrients? _readNutrients() {
    _nutrientProblems.clear();
    final values = <String, double>{};
    for (final kind in allNutrientKinds) {
      final text = _nutrientFields[kind.key]!.text.trim();
      if (text.isEmpty) {
        continue;
      }
      final value = parseAmount(text);
      if (value == null) {
        _nutrientProblems[kind.key] = 'Please enter a number, such as 12.5.';
      } else {
        values[kind.key] = value;
      }
    }
    if (!values.containsKey(energyKey) &&
        !_nutrientProblems.containsKey(energyKey)) {
      _nutrientProblems[energyKey] = 'Please enter the calories.';
    }
    return _nutrientProblems.isEmpty ? Nutrients(values) : null;
  }

  Future<void> _save() async {
    final nameProblem = checkFoodName(_nameField.text);
    final nutrients = _readNutrients();
    setState(() => _nameProblem = nameProblem);
    if (nameProblem != null || nutrients == null) {
      return;
    }

    final actions = FoodActions(widget.appState);
    final food = widget.food;
    String? newFoodId;
    final saved = await saveOrShowError(context, () async {
      if (food == null) {
        final event = await actions.createFood(
          name: _nameField.text,
          measuredIn: _unit,
          nutrientsPer100: nutrients,
        );
        newFoodId = event.id;
        return;
      }
      await actions.changeFood(
        food.id,
        name: _nameField.text,
        nutrientsPer100: nutrients,
      );
    });
    if (saved && mounted) {
      Navigator.of(context).pop(newFoodId);
    }
  }

  Future<void> _delete() async {
    final food = widget.food!;
    final actions = FoodActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteFood(food.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Deleted ${food.name}. Past entries keep it.',
      onUndo: () => actions.restoreFood(food.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.food != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit food' : 'New food')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameField,
            autofocus: !isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameProblem,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Measured in'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'g', label: Text('grams')),
              ButtonSegment(value: 'ml', label: Text('millilitres')),
            ],
            selected: {_unit},
            showSelectedIcon: false,
            // The unit cannot change later: past entries were logged in it.
            onSelectionChanged: isEditing
                ? null
                : (choice) => setState(() => _unit = choice.single),
          ),
          const SizedBox(height: 16),
          Text(
            'Per 100 $_unit (from the label). Only energy is required.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final kind in allNutrientKinds)
            _spaced(
              TextField(
                controller: _nutrientFields[kind.key],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: kind.label.trim(),
                  suffixText: kind.unit,
                  errorText: _nutrientProblems[kind.key],
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (isEditing)
            DeleteButton(label: 'Delete this food', onPressed: _delete),
        ],
      ),
    );
  }
}

/// Puts a little space above a form field, so outlined fields do not
/// touch.
Widget _spaced(Widget field) =>
    Padding(padding: const EdgeInsets.only(top: 12), child: field);
