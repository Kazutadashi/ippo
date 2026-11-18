// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding a food to the food list, or changing one: by typing, or by
/// filling it in from a nutrition label.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_serving.dart';
import '../nutrients.dart';
import '../nutrition_label.dart';
import 'label_paste_dialog.dart';

/// The form for a food: name, unit, serving size, and nutrients per 100
/// g (or ml) or per serving, as on the label.
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
  late final TextEditingController _servingCountField = TextEditingController(
    text: _numberText(widget.food?.serving?.count),
  );
  late final TextEditingController _servingUnitField = TextEditingController(
    text: widget.food?.serving?.unit ?? '',
  );
  late final TextEditingController _servingAmountField = TextEditingController(
    text: _numberText(widget.food?.serving?.amount),
  );
  late final Map<String, TextEditingController> _nutrientFields = {
    for (final kind in allNutrientKinds)
      kind.key: TextEditingController(
        text: _numberText(widget.food?.nutrientsPer100.values[kind.key]),
      ),
  };
  late String _unit = widget.food?.measuredIn ?? 'g';

  /// Whether the nutrient fields hold values per serving (true) or per
  /// 100 g or ml (false). A changed food always starts per 100.
  bool _isPerServing = false;

  String? _nameProblem;
  String? _servingProblem;
  final Map<String, String> _nutrientProblems = {};

  static String _numberText(double? value) =>
      value == null ? '' : formatAmount(value);

  @override
  void dispose() {
    _nameField.dispose();
    _servingCountField.dispose();
    _servingUnitField.dispose();
    _servingAmountField.dispose();
    for (final field in _nutrientFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// Opens the label window, and fills the form with what it read.
  Future<void> _fillInFromLabel() async {
    final reading = await showDialog<LabelReading>(
      context: context,
      builder: (context) => const LabelPasteDialog(),
    );
    if (reading == null) {
      return;
    }
    setState(() {
      final name = reading.name;
      if (name != null && _nameField.text.trim().isEmpty) {
        _nameField.text = name;
      }
      if (widget.food == null) {
        _unit = reading.measuredIn;
      }
      final serving = reading.serving;
      if (serving != null) {
        _servingCountField.text = formatAmount(serving.count);
        _servingUnitField.text = serving.unit;
        _servingAmountField.text = formatAmount(serving.amount);
      }
      _isPerServing = !reading.isPer100;
      for (final kind in allNutrientKinds) {
        final value = reading.nutrients[kind.key];
        _nutrientFields[kind.key]!.text = _numberText(value);
      }
      _nutrientProblems.clear();
      _servingProblem = null;
    });
  }

  /// Reads the serving size fields. Returns null if they are empty, and
  /// notes a problem if they are filled in only partly or wrongly.
  FoodServing? _readServing() {
    final countText = _servingCountField.text.trim();
    final unitText = _servingUnitField.text.trim();
    final amountText = _servingAmountField.text.trim();
    _servingProblem = null;
    if (countText.isEmpty && unitText.isEmpty && amountText.isEmpty) {
      return null;
    }
    final count = parseAmount(countText);
    final amount = parseAmount(amountText);
    if (count == null || count == 0 || amount == null || amount == 0) {
      _servingProblem = 'Fill in all three, such as 9 chips, 28 g.';
      return null;
    }
    if (unitText.isEmpty || unitText.length > maximumUnitNameLength) {
      _servingProblem = 'Name the pieces, such as chips or slices.';
      return null;
    }
    return FoodServing(unit: unitText, count: count, amount: amount);
  }

  /// Reads the typed nutrients and notes any problems. Returns null if
  /// there is a problem.
  Map<String, double>? _readNutrientValues() {
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
    return _nutrientProblems.isEmpty ? values : null;
  }

  Future<void> _save() async {
    final nameProblem = checkFoodName(_nameField.text);
    final serving = _readServing();
    final values = _readNutrientValues();
    final per100 = values == null
        ? null
        : nutrientsPer100From(
            values,
            isPer100: !_isPerServing,
            serving: serving,
          );
    if (values != null && per100 == null) {
      _servingProblem = 'Values per serving need the serving size.';
    }
    setState(() => _nameProblem = nameProblem);
    if (nameProblem != null || per100 == null || _servingProblem != null) {
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
          nutrientsPer100: per100,
          serving: serving,
        );
        newFoodId = event.id;
        return;
      }
      await actions.changeFood(
        food.id,
        name: _nameField.text,
        nutrientsPer100: per100,
        serving: serving,
        removeServing: serving == null && food.serving != null,
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
          OutlinedButton.icon(
            onPressed: _fillInFromLabel,
            icon: const Icon(Icons.receipt_long),
            label: const Text('Fill in from label'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameField,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameProblem,
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Measured in'),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment(value: 'g', label: Text('Grams')),
              ButtonSegment(value: 'ml', label: Text('Millilitres')),
            ],
            selected: {_unit},
            showSelectedIcon: false,
            // The unit cannot change later: past entries were logged in it.
            onSelectionChanged: isEditing
                ? null
                : (choice) => setState(() => _unit = choice.single),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Serving size, as on the label (optional)'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _servingCountField,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'How many'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _servingUnitField,
                  decoration: const InputDecoration(labelText: 'Of what'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _servingAmountField,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Weighs',
                    suffixText: _unit,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (_servingProblem != null) ...[
            const SizedBox(height: 8),
            ProblemText(_servingProblem!),
          ],
          const SizedBox(height: 20),
          const FieldLabel('The values below are per'),
          SegmentedButton<bool>(
            expandedInsets: EdgeInsets.zero,
            segments: [
              ButtonSegment(value: false, label: Text('100 $_unit')),
              const ButtonSegment(value: true, label: Text('Serving')),
            ],
            selected: {_isPerServing},
            showSelectedIcon: false,
            onSelectionChanged: (choice) =>
                setState(() => _isPerServing = choice.single),
          ),
          for (final kind in allNutrientKinds)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
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
