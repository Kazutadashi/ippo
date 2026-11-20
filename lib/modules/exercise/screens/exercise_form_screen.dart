// SPDX-License-Identifier: GPL-3.0-or-later

/// Creating or changing an exercise.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_actions.dart';

/// The form for an exercise: its name and whether it counts reps or
/// seconds.
class ExerciseFormScreen extends StatefulWidget {
  /// Creates the form for a new exercise, or for changing [exercise].
  const ExerciseFormScreen({super.key, required this.appState, this.exercise});

  /// The app-wide state.
  final AppState appState;

  /// The exercise being changed, or null for a new one.
  final Exercise? exercise;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.exercise?.name ?? '',
  );
  late MeasuredIn _measuredIn = widget.exercise?.measuredIn ?? MeasuredIn.reps;
  String? _nameProblem;

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = checkExerciseName(_nameField.text);
    setState(() => _nameProblem = problem);
    if (problem != null) {
      return;
    }
    final actions = ExerciseActions(widget.appState);
    final exercise = widget.exercise;
    final saved = await saveOrShowError(context, () {
      if (exercise == null) {
        return actions.createExercise(
          name: _nameField.text,
          measuredIn: _measuredIn,
        );
      }
      return actions.renameExercise(exercise.id, _nameField.text);
    });
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final exercise = widget.exercise!;
    final actions = ExerciseActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteExercise(exercise.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Deleted ${exercise.name}. Its sets are kept.',
      onUndo: () => actions.restoreExercise(exercise.id),
    );
  }

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => [_nameField.text, _measuredIn.name].join('\n');

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exercise != null;
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
          title: Text(isEditing ? 'Edit exercise' : 'New exercise'),
          actions: [AppBarSaveButton(onPressed: _save)],
        ),
        body: ListView(
          padding: belowNavigationBar(context, const EdgeInsets.all(16)),
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
            if (isEditing) ...[
              // Fixed once created, because past sets were counted in this
              // unit. So it is shown as information, not as a dead control.
              InfoValue(
                label: 'Counted in',
                value: _measuredIn == MeasuredIn.reps ? 'Reps' : 'Seconds',
              ),
              const SizedBox(height: Spacing.tight),
              const NoteText(
                'This cannot be changed, so past sets keep their meaning.',
              ),
            ] else ...[
              const FieldLabel('Counted in'),
              SegmentedButton<MeasuredIn>(
                expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment(value: MeasuredIn.reps, label: Text('Reps')),
                  ButtonSegment(
                    value: MeasuredIn.seconds,
                    label: Text('Seconds'),
                  ),
                ],
                selected: {_measuredIn},
                showSelectedIcon: false,
                onSelectionChanged: (choice) =>
                    setState(() => _measuredIn = choice.single),
              ),
            ],
            if (isEditing)
              DeleteButton(label: 'Delete this exercise', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}
