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
import '../habit_marks.dart';

/// The form for a habit: its name, how often, and its colour, with a
/// preview of how it will look in the grid.
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
              // The preview follows the name as it is typed.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            // Not every habit is for every day: a waiting day between
            // turns is never counted as missed.
            const FieldLabel('How often'),
            _TwoColumns(
              children: [
                for (final preset in HabitFrequency.presets)
                  _Option(
                    label: preset.describe(),
                    isSelected: _preset == preset,
                    onTap: () => setState(() {
                      _preset = preset;
                      _frequencyProblem = null;
                    }),
                  ),
                _Option(
                  label: 'Other',
                  isSelected: _preset == null,
                  onTap: () => setState(() {
                    // From "Every day", start at a frequency that is not
                    // one already offered above.
                    if (_frequency == HabitFrequency.everyDay) {
                      _timesField.text = '2';
                      _daysField.text = '10';
                    }
                    _preset = null;
                  }),
                ),
              ],
            ),
            if (_preset == null) ...[
              const SizedBox(height: Spacing.medium),
              // Reads as a sentence: "2 times every 7 days".
              Row(
                children: [
                  _NumberField(
                    controller: _timesField,
                    label: 'Times',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(width: Spacing.small),
                  const Text('times every'),
                  const SizedBox(width: Spacing.small),
                  _NumberField(
                    controller: _daysField,
                    label: 'Days',
                    onChanged: () => setState(() {}),
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
            const SizedBox(height: 20),
            const FieldLabel('Preview'),
            _HabitPreview(
              name: _nameField.text.trim(),
              color: _color,
              frequency: _frequency,
            ),
            if (isEditing)
              DeleteButton(label: 'Delete this habit', onPressed: _delete),
          ],
        ),
      ),
    );
  }
}

/// Lays out [children] in two equal columns, row by row.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - Spacing.small) / 2;
        return Wrap(
          spacing: Spacing.small,
          runSpacing: Spacing.small,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// One choice of several: outlined, or filled with the accent tint and
/// its label in the accent when chosen, so the choice stands out.
class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isSelected
            ? colors.primary
            : colors.outline.withValues(alpha: 0.6),
        width: isSelected ? 2 : 1,
      ),
    );
    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        shape: shape,
        color: isSelected ? colors.secondaryContainer : Colors.transparent,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.small,
                vertical: Spacing.small,
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The habit as it will look in the grid: its name in its colour, how
/// often under it, and a few days of marks.
class _HabitPreview extends StatelessWidget {
  const _HabitPreview({
    required this.name,
    required this.color,
    required this.frequency,
  });

  /// The name typed so far; empty shows the example name.
  final String name;

  /// The picked colour, or null for the accent.
  final Color? color;

  /// How often, or null while "Other" holds no valid frequency.
  final HabitFrequency? frequency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // A habit that is never saved, only to get its colours.
    final habit = Habit(
      id: '',
      name: name.isEmpty ? 'Read 10 pages' : name,
      valueType: 'yes_no',
      color: color,
      isArchived: false,
      isDeleted: false,
    );
    final markColor = habit.displayColor(theme);
    final frequency = this.frequency;
    return ExcludeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: habit.textColor(theme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (frequency != null)
                      Text(
                        frequency.describe(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              // Today waiting, then three days done, as in the grid.
              Icon(
                Icons.circle_outlined,
                size: 15,
                color: markColor.withValues(alpha: 0.7),
              ),
              for (var day = 0; day < 3; day++) ...[
                const SizedBox(width: 14),
                BoldCheck(size: 18, color: markColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small box for a whole number in the "Other" frequency sentence.
/// [label] is read out by screen readers; the sentence says it on screen.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Semantics(
        label: label,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: (_) => onChanged(),
        ),
      ),
    );
  }
}
