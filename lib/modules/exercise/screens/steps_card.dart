// SPDX-License-Identifier: GPL-3.0-or-later

/// The Exercise page's card for the day's steps.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise_actions.dart';
import '../step_count.dart';

/// The most steps one day can have; more is surely a typo.
const int maximumStepsPerDay = 200000;

/// The steps walked on the day shown, typed in from a watch or phone:
/// one field and Save. The field shows the day's saved count, and Save
/// says "Saved" until the number changes.
class StepsCard extends StatefulWidget {
  /// Creates the card for [date] (`YYYY-MM-DD`), whose saved count is
  /// [saved] (null if none yet).
  const StepsCard({
    super.key,
    required this.appState,
    required this.date,
    required this.saved,
  });

  /// The app-wide state, which writes the events.
  final AppState appState;

  /// The day shown.
  final String date;

  /// The day's saved count, if any.
  final StepCount? saved;

  @override
  State<StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<StepsCard> {
  late final TextEditingController _field = TextEditingController(
    text: _savedText,
  );
  String? _problem;

  String get _savedText {
    final saved = widget.saved;
    return saved == null ? '' : '${saved.steps}';
  }

  @override
  void didUpdateWidget(StepsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another day, or the count changed elsewhere: show the saved one.
    if (oldWidget.date != widget.date ||
        oldWidget.saved?.steps != widget.saved?.steps) {
      _field.text = _savedText;
      _problem = null;
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  bool get _isSaved => _field.text.trim() == _savedText;

  Future<void> _save() async {
    final steps = int.tryParse(_field.text.trim());
    if (steps == null || steps < 0 || steps > maximumStepsPerDay) {
      setState(() => _problem = 'Enter the steps as a whole number.');
      return;
    }
    setState(() => _problem = null);
    HapticFeedback.selectionClick();
    await saveOrShowError(
      context,
      () => ExerciseActions(widget.appState)
          .saveSteps(date: widget.date, steps: steps, existing: widget.saved),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        const CardHeader(icon: Icons.directions_walk, title: 'Steps'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _field,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Steps',
                  errorText: _problem,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: Spacing.small),
            FilledButton.tonal(
              onPressed: _isSaved ? null : _save,
              child: Text(_isSaved && _savedText.isNotEmpty ? 'Saved' : 'Save'),
            ),
          ],
        ),
      ],
    );
  }
}
