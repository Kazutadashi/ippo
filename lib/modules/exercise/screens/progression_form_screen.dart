// SPDX-License-Identifier: GPL-3.0-or-later

/// Creating or changing a progression: its name and ordered steps.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/save_or_show_error.dart';
import '../exercise_actions.dart';
import '../exercise_log.dart';
import '../progression.dart';
import 'step_form_screen.dart';

/// The form for a progression.
class ProgressionFormScreen extends StatefulWidget {
  /// Creates the form for a new progression, or for changing
  /// [progression] if given.
  const ProgressionFormScreen({
    super.key,
    required this.appState,
    this.progression,
  });

  /// The app-wide state.
  final AppState appState;

  /// The progression being changed, or null for a new one.
  final Progression? progression;

  @override
  State<ProgressionFormScreen> createState() => _ProgressionFormScreenState();
}

class _ProgressionFormScreenState extends State<ProgressionFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.progression?.name ?? '',
  );
  late final List<StepDraft> _steps = _draftsFromProgression();
  String? _problem;

  ExerciseLog _currentLog() =>
      ExerciseLog.fromEvents(widget.appState.eventLog?.events ?? []);

  List<StepDraft> _draftsFromProgression() {
    final progression = widget.progression;
    if (progression == null) {
      return [];
    }
    final log = _currentLog();
    return [
      for (final step in progression.steps)
        StepDraft(
          exerciseId: step.exerciseId,
          exerciseName: log.exercises[step.exerciseId]?.name ?? '(unknown)',
          measuredIn: step.measuredIn,
          targetSets: step.targetSets,
          targetPerSet: step.targetPerSet,
        ),
    ];
  }

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  /// Opens the step form; [index] null adds a new step at the end.
  Future<void> _editStep(int? index) async {
    final draft = await Navigator.of(context).push(
      MaterialPageRoute<StepDraft>(
        builder: (context) =>
            StepFormScreen(draft: index == null ? null : _steps[index]),
      ),
    );
    if (draft == null) {
      return;
    }
    setState(() {
      if (index == null) {
        _steps.add(draft);
      } else {
        _steps[index] = draft;
      }
    });
  }

  void _moveStep(int index, int offset) {
    setState(() {
      final step = _steps.removeAt(index);
      _steps.insert(index + offset, step);
    });
  }

  Future<void> _save() async {
    final name = _nameField.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = 'Please enter a name.');
      return;
    }
    if (_steps.isEmpty) {
      setState(() => _problem = 'Please add at least one step.');
      return;
    }
    final actions = ExerciseActions(widget.appState);
    final saved = await saveOrShowError(
      context,
      () => actions.saveProgressionFromDrafts(
        progressionId: widget.progression?.id,
        name: name,
        drafts: _steps,
        log: _currentLog(),
      ),
    );
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final progression = widget.progression!;
    final actions = ExerciseActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteProgression(progression.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${progression.name}. Its sets are kept.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.restoreProgression(progression.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.progression != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit progression' : 'New progression'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameField,
            autofocus: !isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name, for example "Squat progression"',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Steps, easiest first',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (var index = 0; index < _steps.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('${index + 1}.'),
              title: Text(_steps[index].describe()),
              onTap: () => _editStep(index),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: index == 0 ? null : () => _moveStep(index, -1),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: index == _steps.length - 1
                        ? null
                        : () => _moveStep(index, 1),
                  ),
                  IconButton(
                    tooltip: 'Remove step',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _steps.removeAt(index)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editStep(null),
            icon: const Icon(Icons.add),
            label: const Text('Add step'),
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _problem!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (isEditing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              child: Text(
                'Delete this progression',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
