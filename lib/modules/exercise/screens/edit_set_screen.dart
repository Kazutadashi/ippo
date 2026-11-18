// SPDX-License-Identifier: GPL-3.0-or-later

/// Fixing or deleting a logged set.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_actions.dart';
import '../exercise_set.dart';

/// The form for changing one set: reps or seconds, and optional weight
/// and effort. Also deletes the set.
class EditSetScreen extends StatefulWidget {
  /// Creates the form for changing [existingSet] of [exercise].
  const EditSetScreen({
    super.key,
    required this.appState,
    required this.exercise,
    required this.existingSet,
  });

  /// The app-wide state.
  final AppState appState;

  /// The exercise the set belongs to.
  final Exercise exercise;

  /// The set being changed.
  final ExerciseSet existingSet;

  @override
  State<EditSetScreen> createState() => _EditSetScreenState();
}

class _EditSetScreenState extends State<EditSetScreen> {
  late final TextEditingController _valueField = TextEditingController(
    text: '${widget.existingSet.value}',
  );
  late final TextEditingController _weightField = TextEditingController(
    text: widget.existingSet.weightKg == null
        ? ''
        : formatAmount(widget.existingSet.weightKg!),
  );
  late final TextEditingController _reserveField = TextEditingController(
    text: '${widget.existingSet.repsInReserve ?? ''}',
  );
  String? _valueProblem;
  String? _weightProblem;
  String? _reserveProblem;

  @override
  void dispose() {
    _valueField.dispose();
    _weightField.dispose();
    _reserveField.dispose();
    super.dispose();
  }

  bool get _isReps => widget.exercise.measuredIn == MeasuredIn.reps;

  Future<void> _save() async {
    final value = int.tryParse(_valueField.text.trim());
    final weightText = _weightField.text.trim();
    final weightKg = weightText.isEmpty ? null : parseAmount(weightText);
    final reserveText = _reserveField.text.trim();
    final repsInReserve = reserveText.isEmpty
        ? null
        : int.tryParse(reserveText);
    setState(() {
      _valueProblem = value == null || value < 0
          ? 'Please enter a whole number.'
          : null;
      _weightProblem = weightText.isNotEmpty && weightKg == null
          ? 'Please enter a number, or leave empty.'
          : null;
      _reserveProblem =
          reserveText.isNotEmpty && (repsInReserve == null || repsInReserve < 0)
          ? 'Please enter a whole number, or leave empty.'
          : null;
    });
    if (value == null ||
        _valueProblem != null ||
        _weightProblem != null ||
        _reserveProblem != null) {
      return;
    }

    final actions = ExerciseActions(widget.appState);
    final saved = await saveOrShowError(
      context,
      () => actions.changeSet(
        widget.existingSet,
        measuredIn: widget.exercise.measuredIn,
        value: value,
        weightKg: weightKg,
        repsInReserve: repsInReserve,
      ),
    );
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final setId = widget.existingSet.id;
    final actions = ExerciseActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteSet(setId),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Set deleted.',
      onUndo: () => actions.restoreSet(setId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _valueField,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _isReps ? 'Reps' : 'Seconds',
              errorText: _valueProblem,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightField,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Added weight (optional)',
              suffixText: 'kg',
              errorText: _weightProblem,
            ),
          ),
          if (_isReps) const SizedBox(height: 12),
          if (_isReps)
            TextField(
              controller: _reserveField,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps in reserve (optional)',
                helperText: 'How many more reps you could have done.',
                errorText: _reserveProblem,
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
          DeleteButton(label: 'Delete this set', onPressed: _delete),
        ],
      ),
    );
  }
}
