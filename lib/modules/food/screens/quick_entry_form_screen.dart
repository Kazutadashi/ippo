// SPDX-License-Identifier: GPL-3.0-or-later

/// Logging a quick entry (a name and calories typed in directly), or
/// changing one.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/clock_time.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/time_fields.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'food_entry_form_screen.dart';
import 'nutrition_fields.dart';

/// The nutrients a quick entry asks for. Energy is required.
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

  /// Whether [date] is today, so the time starts at now.
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
    for (final key in allNutrientFieldKeys)
      key: TextEditingController(
        text: widget.entry?.nutrients.values[key] == null
            ? ''
            : formatAmount(widget.entry!.nutrients.values[key]!),
      ),
  };
  String? _nameProblem;
  String? _energyProblem;
  final Map<String, String?> _nutrientProblems = {};

  /// When it was eaten (see [startingEntryTime]).
  late ClockTime? _time = startingEntryTime(
    entryTime: widget.entry?.time,
    isNew: widget.entry == null,
    isToday: widget.isToday,
  );

  /// Whether the less common nutrients are shown: when any is filled in.
  late bool _isShowingMore = moreNutrientKeys.any(
    (key) => _nutrientFields[key]!.text.isNotEmpty,
  );

  @override
  void dispose() {
    _nameField.dispose();
    for (final field in _nutrientFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// Reads the typed nutrients. Empty fields are left out: they are not
  /// known, which is different from zero. Returns null (and shows why)
  /// if energy is missing, or something typed is not a number.
  Nutrients? _readNutrients() {
    final values = <String, double>{};
    _nutrientProblems.clear();
    for (final key in allNutrientFieldKeys) {
      final text = _nutrientFields[key]!.text.trim();
      if (text.isEmpty) {
        continue;
      }
      final value = parseAmount(text);
      if (value == null) {
        _nutrientProblems[key] = 'Not a number';
      } else {
        values[key] = value;
      }
    }
    if (!values.containsKey(energyKey) &&
        _nutrientProblems[energyKey] == null) {
      _energyProblem = 'Please enter the energy.';
    }
    setState(() {});
    if (_energyProblem != null || _nutrientProblems.isNotEmpty) {
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
          time: _time?.toString(),
          name: _nameField.text,
          nutrients: nutrients,
        );
      }
      return actions.changeQuickEntry(
        entry,
        name: _nameField.text,
        nutrients: nutrients,
        time: _time?.toString(),
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

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => [
    _nameField.text,
    _time,
    for (final field in _nutrientFields.values) field.text,
  ].join('\n');

  @override
  Widget build(BuildContext context) {
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
          title: const Text('Quick food'),
          actions: [AppBarSaveButton(onPressed: _save)],
        ),
        // The same cards and fields as "New food", so both read the same.
        body: ListView(
          padding: belowNavigationBar(
            context,
            const EdgeInsets.fromLTRB(16, 8, 16, 32),
          ),
          children: [
            SectionCard(
              children: [
                const CardHeader(icon: Icons.restaurant, title: 'Food'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameField,
                  autofocus: widget.entry == null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'What did you eat?',
                    hintText: 'Restaurant lunch',
                    errorText: _nameProblem,
                  ),
                ),
                const SizedBox(height: 12),
                TimeField(
                  label: 'Eaten at',
                  time: _time,
                  onChanged: (time) => setState(() => _time = time),
                ),
              ],
            ),
            SectionCard(
              children: [
                const CardHeader(
                  icon: Icons.local_fire_department,
                  title: 'Nutrition',
                ),
                const NoteText('For the whole portion. Only energy is needed.'),
                const SizedBox(height: 16),
                NutritionFields(
                  fields: _nutrientFields,
                  problems: {energyKey: _energyProblem, ..._nutrientProblems},
                  isShowingMore: _isShowingMore,
                  onShowMoreChanged: (show) =>
                      setState(() => _isShowingMore = show),
                ),
              ],
            ),
            if (widget.entry != null)
              DeleteButton(label: 'Delete this entry', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}
