// SPDX-License-Identifier: GPL-3.0-or-later

/// Editing one step of a progression: the exercise and its target.
library;

import 'package:material_ui/material_ui.dart';

import '../exercise.dart';
import '../exercise_actions.dart';

/// The form for one step. Closes with the finished [StepDraft].
class StepFormScreen extends StatefulWidget {
  /// Creates the form, starting from [draft] if editing a step.
  const StepFormScreen({super.key, this.draft});

  /// The step being edited, or null for a new step.
  final StepDraft? draft;

  @override
  State<StepFormScreen> createState() => _StepFormScreenState();
}

class _StepFormScreenState extends State<StepFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.draft?.exerciseName ?? '',
  );
  late final TextEditingController _setsField = TextEditingController(
    text: '${widget.draft?.targetSets ?? 3}',
  );
  late final TextEditingController _perSetField = TextEditingController(
    text: widget.draft == null ? '' : '${widget.draft!.targetPerSet}',
  );
  late MeasuredIn _measuredIn = widget.draft?.measuredIn ?? MeasuredIn.reps;
  String? _nameProblem;
  String? _setsProblem;
  String? _perSetProblem;

  @override
  void dispose() {
    _nameField.dispose();
    _setsField.dispose();
    _perSetField.dispose();
    super.dispose();
  }

  /// A step's exercise keeps its unit once saved: its past sets were
  /// counted in it.
  bool get _canChangeUnit => widget.draft?.exerciseId == null;

  void _done() {
    final targetSets = int.tryParse(_setsField.text.trim());
    final targetPerSet = int.tryParse(_perSetField.text.trim());
    setState(() {
      _nameProblem = checkExerciseName(_nameField.text);
      _setsProblem = targetSets == null || targetSets < 1
          ? 'Please enter a whole number, 1 or more.'
          : null;
      _perSetProblem = targetPerSet == null || targetPerSet < 1
          ? 'Please enter a whole number, 1 or more.'
          : null;
    });
    if (_nameProblem != null || targetSets == null || targetPerSet == null) {
      return;
    }
    if (_setsProblem != null || _perSetProblem != null) {
      return;
    }
    Navigator.of(context).pop(
      StepDraft(
        exerciseId: widget.draft?.exerciseId,
        exerciseName: _nameField.text.trim(),
        measuredIn: _measuredIn,
        targetSets: targetSets,
        targetPerSet: targetPerSet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.draft == null ? 'New step' : 'Step')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameField,
            autofocus: widget.draft == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Exercise',
              helperText: 'An exercise you already have is reused by name.',
              errorText: _nameProblem,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<MeasuredIn>(
            segments: const [
              ButtonSegment(value: MeasuredIn.reps, label: Text('Reps')),
              ButtonSegment(value: MeasuredIn.seconds, label: Text('Seconds')),
            ],
            selected: {_measuredIn},
            showSelectedIcon: false,
            onSelectionChanged: _canChangeUnit
                ? (choice) => setState(() => _measuredIn = choice.single)
                : null,
          ),
          const SizedBox(height: 16),
          const Text('Target to move up to the next step'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsField,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Sets',
                    errorText: _setsProblem,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('×'),
              ),
              Expanded(
                child: TextField(
                  controller: _perSetField,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _measuredIn == MeasuredIn.reps
                        ? 'Reps per set'
                        : 'Seconds per set',
                    errorText: _perSetProblem,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _done, child: const Text('Done')),
        ],
      ),
    );
  }
}
