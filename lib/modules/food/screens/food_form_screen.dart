// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding a food to the food list, or changing one: by typing, or by
/// pasting its nutrition label.
///
/// The form follows the label: name, serving size, then nutrition, with
/// the less common nutrients tucked away until needed. Save is in the
/// top bar, so it is always in reach.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_serving.dart';
import '../nutrients.dart';
import '../nutrition_label.dart';
import 'label_paste_screen.dart';
import 'nutrition_fields.dart';

/// The form for a food. When adding, closes with the new food's id.
class FoodFormScreen extends StatefulWidget {
  /// Creates the form for a new food, with [initialName] already typed
  /// (for example what was searched for).
  const FoodFormScreen.add({
    super.key,
    required this.appState,
    this.initialName = '',
  }) : food = null;

  /// Creates the form for changing [food].
  const FoodFormScreen.edit({
    super.key,
    required this.appState,
    required Food this.food,
  }) : initialName = '';

  /// The app-wide state.
  final AppState appState;

  /// The name a new food starts with.
  final String initialName;

  /// The food to change, when editing.
  final Food? food;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.food?.name ?? widget.initialName,
  );

  /// The ingredients, as on the label.
  late final TextEditingController _ingredientsField = TextEditingController(
    text: widget.food?.ingredients ?? '',
  );

  /// The serving as typed, such as "9 chips".
  late final TextEditingController _servingField = TextEditingController(
    text: _startingServingText,
  );

  /// The serving's weight, such as "28".
  late final TextEditingController _weightField = TextEditingController(
    text: _numberText(widget.food?.serving?.amount),
  );

  late final TextEditingController _energyField = TextEditingController(
    text: _numberText(_startingValue(energyKey)),
  );
  late final Map<String, TextEditingController> _nutrientFields = {
    for (final key in [...mainNutrientKeys, ...moreNutrientKeys])
      key: TextEditingController(text: _numberText(_startingValue(key))),
  };

  late String _unit = widget.food?.measuredIn ?? 'g';

  /// Whether the nutrition values are per 100 g (or ml) rather than per
  /// serving. Only matters when a serving size is filled in; without one,
  /// values are always per 100.
  bool _isPer100 = false;

  /// Whether the less common nutrients are shown.
  late bool _isShowingMore = moreNutrientKeys.any(
    (key) => _nutrientFields[key]!.text.isNotEmpty,
  );

  String? _nameProblem;
  String? _servingProblem;
  String? _energyProblem;
  final Map<String, String> _nutrientProblems = {};

  static String _numberText(double? value) =>
      value == null ? '' : formatAmount(value);

  String get _startingServingText {
    final serving = widget.food?.serving;
    return serving == null ? '' : writeServingText(serving);
  }

  /// A stored value, shown per serving if the food has a serving size
  /// (as on its label), otherwise per 100.
  double? _startingValue(String key) {
    final food = widget.food;
    final per100 = food?.nutrientsPer100.values[key];
    final serving = food?.serving;
    if (per100 == null || serving == null) {
      return per100;
    }
    return roundToTenth(per100 * serving.amount / 100);
  }

  @override
  void dispose() {
    _nameField.dispose();
    _ingredientsField.dispose();
    _servingField.dispose();
    _weightField.dispose();
    _energyField.dispose();
    for (final field in _nutrientFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// The serving weight typed, or null if none.
  double? get _servingWeight {
    final weight = parseAmount(_weightField.text);
    return weight == null || weight == 0 ? null : weight;
  }

  /// Whether the nutrition values are per serving.
  bool get _isPerServing => _servingWeight != null && !_isPer100;

  /// Says what the nutrition values are per, for example "Per serving
  /// (28 g)" or "Per 100 g".
  String get _basisText {
    final weight = _servingWeight;
    if (_isPerServing && weight != null) {
      return 'Per serving (${formatAmount(weight)} $_unit)';
    }
    return 'Per 100 $_unit';
  }

  Future<void> _pasteLabel() async {
    final reading = await Navigator.of(context).push<LabelReading>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const LabelPasteScreen(),
      ),
    );
    if (reading == null || !mounted) {
      return;
    }
    final filled = _fillFrom(reading);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filled in $filled values from the label.')),
    );
  }

  /// Fills the form from [reading]. Returns how many values were filled.
  int _fillFrom(LabelReading reading) {
    var filled = 0;
    setState(() {
      final name = reading.name;
      if (name != null && _nameField.text.trim().isEmpty) {
        _nameField.text = name;
        filled++;
      }
      if (widget.food == null) {
        _unit = reading.measuredIn;
      }
      final serving = reading.serving;
      if (serving != null) {
        _servingField.text = writeServingText(serving);
        _weightField.text = formatAmount(serving.amount);
        filled++;
      }
      _isPer100 = reading.isPer100;
      final energy = reading.nutrients[energyKey];
      _energyField.text = _numberText(energy);
      if (energy != null) {
        filled++;
      }
      for (final entry in _nutrientFields.entries) {
        final value = reading.nutrients[entry.key];
        entry.value.text = _numberText(value);
        if (value != null) {
          filled++;
        }
      }
      final ingredients = reading.ingredients;
      if (ingredients != null) {
        _ingredientsField.text = ingredients;
        filled++;
      }
      _isShowingMore = moreNutrientKeys.any(
        (key) => reading.nutrients.containsKey(key),
      );
      _clearProblems();
      // A label with values per serving needs the serving's weight.
      if (!reading.isPer100 && serving == null) {
        _servingProblem =
            'The label\'s values are per serving: add its weight.';
      }
    });
    return filled;
  }

  void _clearProblems() {
    _nameProblem = null;
    _servingProblem = null;
    _energyProblem = null;
    _nutrientProblems.clear();
  }

  /// Reads the serving fields. Notes a problem if they do not make sense.
  FoodServing? _readServing() {
    final weight = _servingWeight;
    final servingText = _servingField.text.trim();
    if (weight == null) {
      if (servingText.isNotEmpty || _weightField.text.trim().isNotEmpty) {
        _servingProblem = 'Add the serving\'s weight, such as 28.';
      }
      return null;
    }
    // Keep a saved serving exactly as it was if its text is unchanged,
    // so "2/3 cup" does not become "0.7 cup".
    final saved = widget.food?.serving;
    if (saved != null && servingText == _startingServingText) {
      return FoodServing(unit: saved.unit, count: saved.count, amount: weight);
    }
    final typed = readServingText(servingText);
    if (servingText.isEmpty || typed == null) {
      return FoodServing(unit: 'serving', count: 1, amount: weight);
    }
    if (typed.unit.length > maximumUnitNameLength) {
      _servingProblem = 'Please use a shorter name, such as chips.';
      return null;
    }
    return FoodServing(unit: typed.unit, count: typed.count, amount: weight);
  }

  /// Reads the nutrition fields, as typed (per serving or per 100).
  Map<String, double>? _readValues() {
    final values = <String, double>{};
    final energy = parseAmount(_energyField.text);
    if (energy == null) {
      _energyProblem = _energyField.text.trim().isEmpty
          ? 'Please enter the energy.'
          : 'Please enter a number.';
    } else {
      values[energyKey] = energy;
    }
    for (final entry in _nutrientFields.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) {
        continue;
      }
      final value = parseAmount(text);
      if (value == null) {
        _nutrientProblems[entry.key] = 'Not a number';
      } else {
        values[entry.key] = value;
      }
    }
    return _energyProblem == null && _nutrientProblems.isEmpty ? values : null;
  }

  Future<void> _save() async {
    setState(_clearProblems);
    _nameProblem = checkFoodName(_nameField.text);
    final serving = _readServing();
    final values = _readValues();
    setState(() {});
    if (_nameProblem != null || _servingProblem != null || values == null) {
      return;
    }
    final per100 = nutrientsPer100From(
      values,
      isPer100: !_isPerServing,
      serving: serving,
    )!;

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
          ingredients: _ingredientsField.text,
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
        ingredients: _ingredientsField.text,
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

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => [
    _nameField.text,
    _ingredientsField.text,
    _servingField.text,
    _weightField.text,
    _unit,
    _isPer100,
    _energyField.text,
    for (final field in _nutrientFields.values) field.text,
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.food != null;

    return DiscardGuard(
      snapshot: _snapshot,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close without saving',
            icon: const Icon(Icons.close),
            // Through the discard guard, like the back button.
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(isEditing ? 'Edit food' : 'New food'),
          actions: [AppBarSaveButton(onPressed: _save)],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Tonal, so it reads as a button, never as an empty field.
            FilledButton.tonalIcon(
              onPressed: _pasteLabel,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Fill in from a label'),
            ),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.restaurant, title: 'Food'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameField,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: _nameProblem,
                  ),
                ),
              ],
            ),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.scale, title: 'Serving size'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _servingField,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Serving',
                          hintText: '2 slices',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightField,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Weight',
                          suffixText: _unit,
                        ),
                        // Redraw: the nutrition card says what its values
                        // are per.
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  expandedInsets: EdgeInsets.zero,
                  segments: const [
                    ButtonSegment(value: 'g', label: Text('Grams')),
                    ButtonSegment(value: 'ml', label: Text('Millilitres')),
                  ],
                  selected: {_unit},
                  showSelectedIcon: false,
                  // Fixed once saved: past entries were logged in it.
                  onSelectionChanged: isEditing
                      ? null
                      : (choice) => setState(() => _unit = choice.single),
                ),
                if (_servingProblem != null) ...[
                  const SizedBox(height: 8),
                  ProblemText(_servingProblem!),
                ],
              ],
            ),
            SectionCard(
              children: [
                const CardHeader(
                  icon: Icons.local_fire_department,
                  title: 'Nutrition',
                ),
                NoteText(_basisText),
                // Only with a serving size can values be per serving.
                if (_servingWeight != null) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    expandedInsets: EdgeInsets.zero,
                    segments: [
                      const ButtonSegment(
                        value: false,
                        label: Text('Per serving'),
                      ),
                      ButtonSegment(value: true, label: Text('Per 100 $_unit')),
                    ],
                    selected: {_isPer100},
                    showSelectedIcon: false,
                    onSelectionChanged: (choice) =>
                        setState(() => _isPer100 = choice.single),
                  ),
                ],
                const SizedBox(height: 16),
                NutritionFields(
                  fields: {energyKey: _energyField, ..._nutrientFields},
                  problems: {energyKey: _energyProblem, ..._nutrientProblems},
                  isShowingMore: _isShowingMore,
                  onShowMoreChanged: (show) =>
                      setState(() => _isShowingMore = show),
                ),
              ],
            ),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.list_alt, title: 'Ingredients'),
                TextField(
                  controller: _ingredientsField,
                  minLines: 2,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ingredients, as on the label',
                  ),
                ),
              ],
            ),
            if (isEditing)
              DeleteButton(label: 'Delete this food', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}
