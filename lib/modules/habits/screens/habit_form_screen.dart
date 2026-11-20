// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding a habit, or renaming or deleting one.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/theme.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/color_circles.dart';
import '../../../core/widgets/color_wheel.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../habit.dart';
import '../habit_actions.dart';

/// The form for a habit: its name and colour.
class HabitFormScreen extends StatefulWidget {
  /// Creates the form for a new habit, or for changing [habit].
  const HabitFormScreen({super.key, required this.appState, this.habit});

  /// The app-wide state.
  final AppState appState;

  /// The habit being changed, or null for a new one.
  final Habit? habit;

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.habit?.name ?? '',
  );
  String? _nameProblem;

  /// The picked colour, or null for the accent colour.
  late Color? _color = widget.habit?.color;

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = checkHabitName(_nameField.text);
    setState(() => _nameProblem = problem);
    if (problem != null) {
      return;
    }
    final actions = HabitActions(widget.appState);
    final habit = widget.habit;
    final saved = await saveOrShowError(context, () {
      if (habit == null) {
        return actions.createHabit(_nameField.text, color: _color);
      }
      return actions.changeHabit(habit, _nameField.text, _color);
    });
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final habit = widget.habit!;
    final actions = HabitActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteHabit(habit.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: 'Deleted ${habit.name}. Its past days are kept.',
      onUndo: () => actions.restoreHabit(habit.id),
    );
  }

  /// "Default" (the accent colour) first, then the same colours as the
  /// accent colours in Settings, then any colour from a wheel.
  List<Widget> _colorCircles(BuildContext context) {
    final picked = _color?.toARGB32();
    return [
      ColorCircle(
        choice: AccentChoice('Default', Theme.of(context).colorScheme.primary),
        purpose: 'habit colour, the same as the accent colour',
        icon: Icons.auto_awesome,
        isSelected: picked == null,
        onTap: () => setState(() => _color = null),
      ),
      for (final choice in accentChoices)
        ColorCircle(
          choice: choice,
          purpose: 'habit colour',
          isSelected: picked == choice.color.toARGB32(),
          onTap: () => setState(() => _color = choice.color),
        ),
      // Any other colour, from a wheel.
      CustomColorCircle(
        color: _color == null || isPresetColor(_color!) ? null : _color,
        purpose: 'habit colour',
        onPicked: (color) => setState(() => _color = color),
      ),
    ];
  }

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => [_nameField.text, _color?.toARGB32()].join('\n');

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habit != null;
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
          title: Text(isEditing ? 'Edit habit' : 'New habit'),
          actions: [AppBarSaveButton(onPressed: _save)],
        ),
        body: ListView(
          padding: belowNavigationBar(
            context,
            const EdgeInsets.all(Spacing.screen),
          ),
          children: [
            TextField(
              controller: _nameField,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Habit',
                hintText: 'Read 10 pages',
                errorText: _nameProblem,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Colour'),
            ColorCircleGrid(circles: _colorCircles(context)),
            if (isEditing)
              DeleteButton(label: 'Delete this habit', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}
