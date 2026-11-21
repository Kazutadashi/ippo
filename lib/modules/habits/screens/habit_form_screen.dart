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
import '../habit_frequency.dart';

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

  /// How often, when one of the presets is chosen; null when "Other" is.
  late HabitFrequency? _preset = _startingPreset;

  /// "Other": how many times, and in how many days.
  late final TextEditingController _timesField = TextEditingController(
    text: '${widget.habit?.frequency.times ?? 1}',
  );
  late final TextEditingController _daysField = TextEditingController(
    text: '${widget.habit?.frequency.perDays ?? 1}',
  );
  String? _frequencyProblem;

  /// The habit's frequency if it is a preset (every day for a new one),
  /// else null, which opens "Other".
  HabitFrequency? get _startingPreset {
    final frequency = widget.habit?.frequency ?? HabitFrequency.everyDay;
    return HabitFrequency.presets.contains(frequency) ? frequency : null;
  }

  /// The frequency chosen: a preset, or what is typed under "Other";
  /// null if what is typed is not a frequency.
  HabitFrequency? get _frequency {
    final preset = _preset;
    if (preset != null) {
      return preset;
    }
    final times = int.tryParse(_timesField.text.trim());
    final days = int.tryParse(_daysField.text.trim());
    if (times == null || days == null) {
      return null;
    }
    if (times < 1 || days < 1 || times > days || days > 365) {
      return null;
    }
    return HabitFrequency(times, days);
  }

  @override
  void dispose() {
    _nameField.dispose();
    _timesField.dispose();
    _daysField.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = checkHabitName(_nameField.text);
    final frequency = _frequency;
    setState(() {
      _nameProblem = problem;
      _frequencyProblem = frequency == null
          ? 'Enter how many times (at least 1) in how many days (up to '
                '365, and at least as many as the times).'
          : null;
    });
    if (problem != null || frequency == null) {
      return;
    }
    final actions = HabitActions(widget.appState);
    final habit = widget.habit;
    final saved = await saveOrShowError(context, () {
      if (habit == null) {
        return actions.createHabit(
          _nameField.text,
          color: _color,
          frequency: frequency,
        );
      }
      return actions.changeHabit(
        habit,
        _nameField.text,
        _color,
        newFrequency: frequency,
      );
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
      // Each colour as it will show on the cards, not the raw colour.
      for (final choice in accentChoices)
        ColorCircle(
          choice: AccentChoice(
            choice.name,
            habitColourAsShown(choice.color, Theme.of(context)),
          ),
          purpose: 'habit colour',
          isSelected: picked == choice.color.toARGB32(),
          onTap: () => setState(() => _color = choice.color),
        ),
      // Any other colour, from a wheel.
      CustomColorCircle(
        color: _color == null || isPresetColor(_color!) ? null : _color,
        purpose: 'habit colour',
        onPicked: (color) => setState(() => _color = color),
        asShown: (color) => habitColourAsShown(color, Theme.of(context)),
      ),
    ];
  }

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => [
    _nameField.text,
    _color?.toARGB32(),
    _preset?.toJson(),
    _timesField.text,
    _daysField.text,
  ].join('\n');

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
            // Not every habit is for every day: a waiting day between
            // turns is never counted as missed.
            const FieldLabel('How often'),
            Wrap(
              spacing: Spacing.tight,
              runSpacing: Spacing.tight,
              children: [
                for (final preset in HabitFrequency.presets)
                  ChoiceChip(
                    label: Text(preset.describe()),
                    selected: _preset == preset,
                    onSelected: (_) => setState(() {
                      _preset = preset;
                      _frequencyProblem = null;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Other'),
                  selected: _preset == null,
                  onSelected: (_) => setState(() => _preset = null),
                ),
              ],
            ),
            if (_preset == null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _timesField,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Times'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Spacing.small),
                  const Text('every'),
                  const SizedBox(width: Spacing.small),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _daysField,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Days'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Spacing.small),
                  const Text('days'),
                ],
              ),
            ],
            if (_frequencyProblem != null) ...[
              const SizedBox(height: 8),
              ProblemText(_frequencyProblem!),
            ],
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
