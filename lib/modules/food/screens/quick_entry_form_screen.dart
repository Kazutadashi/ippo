// SPDX-License-Identifier: GPL-3.0-or-later

/// Logging a quick entry (a name and calories typed in directly), or
/// changing one.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'meal_picker.dart';

/// The nutrients a quick entry asks for. Energy is required.
const List<String> _quickEntryNutrientKeys = [
  energyKey,
  'proteins_g',
  'carbohydrates_g',
  'fat_g',
];

/// The form for a quick entry. Closes with `true` when something was
/// saved or deleted.
class QuickEntryFormScreen extends StatefulWidget {
  /// Creates the form for a new quick entry on [date].
  const QuickEntryFormScreen.add({
    super.key,
    required this.appState,
    required String this.date,
    required this.isToday,
  }) : entry = null;

  /// Creates the form for changing [entry].
  const QuickEntryFormScreen.edit({
    super.key,
    required this.appState,
    required FoodEntry this.entry,
  }) : date = null,
       isToday = false;

  /// The app-wide state.
  final AppState appState;

  /// The day to log on (`YYYY-MM-DD`), when adding.
  final String? date;

  /// Whether [date] is today, so the entry gets the current time.
  final bool isToday;

  /// The entry to change, when editing.
  final FoodEntry? entry;

  @override
  State<QuickEntryFormScreen> createState() => _QuickEntryFormScreenState();
}

class _QuickEntryFormScreenState extends State<QuickEntryFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.entry?.name ?? '',
  );
  late final Map<String, TextEditingController> _nutrientFields = {
    for (final key in _quickEntryNutrientKeys)
      key: TextEditingController(
        text: widget.entry?.nutrients.values[key] == null
            ? ''
            : formatAmount(widget.entry!.nutrients.values[key]!),
      ),
  };
  late Meal _meal = widget.entry?.meal ?? guessMeal(DateTime.now());
  String? _nameProblem;
  String? _energyProblem;

  @override
  void dispose() {
    _nameField.dispose();
    for (final field in _nutrientFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// Reads the typed nutrients. Empty optional fields are left out.
  /// Returns null (and shows why) if energy is missing or invalid.
  Nutrients? _readNutrients() {
    final values = <String, double>{};
    for (final key in _quickEntryNutrientKeys) {
      final text = _nutrientFields[key]!.text;
      final value = parseAmount(text);
      if (value != null) {
        values[key] = value;
      }
    }
    if (!values.containsKey(energyKey)) {
      setState(() => _energyProblem = 'Please enter the calories.');
      return null;
    }
    return Nutrients(values);
  }

  Future<void> _save() async {
    final nameProblem = checkFoodName(_nameField.text);
    setState(() {
      _nameProblem = nameProblem;
      _energyProblem = null;
    });
    final nutrients = _readNutrients();
    if (nameProblem != null || nutrients == null) {
      return;
    }

    final actions = FoodActions(widget.appState);
    final entry = widget.entry;
    final saved = await saveOrShowError(context, () {
      if (entry == null) {
        return actions.recordQuickEntry(
          date: widget.date!,
          time: widget.isToday ? formatTimeOfDay(DateTime.now()) : null,
          meal: _meal,
          name: _nameField.text,
          nutrients: nutrients,
        );
      }
      return actions.changeQuickEntry(
        entry,
        name: _nameField.text,
        nutrients: nutrients,
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
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${entry.name}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.restoreEntry(entry.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kindsByKey = {for (final kind in allNutrientKinds) kind.key: kind};
    return Scaffold(
      appBar: AppBar(title: const Text('Quick entry')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameField,
            autofocus: widget.entry == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What did you eat?',
              errorText: _nameProblem,
            ),
          ),
          for (final key in _quickEntryNutrientKeys)
            TextField(
              controller: _nutrientFields[key],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: key == energyKey
                    ? 'Energy'
                    : '${kindsByKey[key]!.label} (optional)',
                suffixText: kindsByKey[key]!.unit,
                errorText: key == energyKey ? _energyProblem : null,
              ),
            ),
          const SizedBox(height: 16),
          MealPicker(
            selected: _meal,
            onChanged: (meal) => setState(() => _meal = meal),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (widget.entry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              child: Text(
                'Delete this entry',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
