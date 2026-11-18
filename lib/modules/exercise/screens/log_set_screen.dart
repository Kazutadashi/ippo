// SPDX-License-Identifier: GPL-3.0-or-later

/// Logging one set, or changing or deleting a logged set.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../exercise.dart';
import '../exercise_actions.dart';
import '../exercise_log.dart';
import '../exercise_set.dart';
import '../progression.dart';

/// The form for one set: reps or seconds, and optional weight and effort.
class LogSetScreen extends StatefulWidget {
  /// Creates the form for a new set of [exercise] on [date]. If the set
  /// is part of [progression], [stepNumber] is the current step.
  const LogSetScreen.add({
    super.key,
    required this.appState,
    required this.exercise,
    required String this.date,
    required this.progression,
    required this.stepNumber,
    required this.startValue,
  }) : existingSet = null;

  /// Creates the form for changing [existingSet] of [exercise].
  const LogSetScreen.edit({
    super.key,
    required this.appState,
    required this.exercise,
    required ExerciseSet this.existingSet,
  }) : date = null,
       progression = null,
       stepNumber = null,
       startValue = null;

  /// The app-wide state.
  final AppState appState;

  /// The exercise done.
  final Exercise exercise;

  /// The day to log on (`YYYY-MM-DD`), when adding.
  final String? date;

  /// The progression the set belongs to, if any, when adding.
  final Progression? progression;

  /// The current step of [progression], when adding.
  final int? stepNumber;

  /// The value to start with, usually the last set's, when adding.
  final int? startValue;

  /// The set being changed, when editing.
  final ExerciseSet? existingSet;

  @override
  State<LogSetScreen> createState() => _LogSetScreenState();
}

class _LogSetScreenState extends State<LogSetScreen> {
  late final TextEditingController _valueField = TextEditingController(
    text: '${widget.existingSet?.value ?? widget.startValue ?? ''}',
  );
  late final TextEditingController _weightField = TextEditingController(
    text: widget.existingSet?.weightKg == null
        ? ''
        : formatAmount(widget.existingSet!.weightKg!),
  );
  late final TextEditingController _reserveField = TextEditingController(
    text: '${widget.existingSet?.repsInReserve ?? ''}',
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

  /// Adds [change] to the typed value, for the − and + buttons.
  void _adjustValue(int change) {
    final current = int.tryParse(_valueField.text.trim()) ?? 0;
    final adjusted = (current + change).clamp(0, 100000);
    setState(() => _valueField.text = '$adjusted');
  }

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
    final existingSet = widget.existingSet;
    final saved = await saveOrShowError(context, () {
      if (existingSet != null) {
        return actions.changeSet(
          existingSet,
          measuredIn: widget.exercise.measuredIn,
          value: value,
          weightKg: weightKg,
          repsInReserve: repsInReserve,
        );
      }
      final log = ExerciseLog.fromEvents(
        widget.appState.eventLog?.events ?? [],
      );
      final setsSoFar = log.setsOn(widget.date!, widget.exercise.id).length;
      return actions.recordSet(
        date: widget.date!,
        exercise: widget.exercise,
        setNumber: setsSoFar + 1,
        value: value,
        weightKg: weightKg,
        repsInReserve: repsInReserve,
        progression: widget.progression,
        stepNumber: widget.stepNumber,
      );
    });
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final existingSet = widget.existingSet!;
    final actions = ExerciseActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteSet(existingSet.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Set deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.restoreSet(existingSet.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.progression?.stepAt(widget.stepNumber ?? 1);
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (step != null) Text('Target: ${step.describeTarget()}'),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'One less',
                icon: const Icon(Icons.remove),
                onPressed: () => _adjustValue(-1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _valueField,
                  autofocus: widget.existingSet == null,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: InputDecoration(
                    labelText: _isReps ? 'Reps' : 'Seconds',
                    errorText: _valueProblem,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'One more',
                icon: const Icon(Icons.add),
                onPressed: () => _adjustValue(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightField,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Added weight (optional)',
              suffixText: 'kg',
              errorText: _weightProblem,
            ),
          ),
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
          FilledButton(onPressed: _save, child: const Text('Save set')),
          if (widget.existingSet != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              child: Text(
                'Delete this set',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
