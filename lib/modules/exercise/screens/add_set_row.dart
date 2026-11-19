// SPDX-License-Identifier: GPL-3.0-or-later

/// Adding a set straight from an exercise's card: − 17 reps + and
/// "Add set".
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../exercise.dart';

/// The reps (or seconds) of the next set, with − and + beside them, and
/// a button that adds the set.
///
/// It starts at the last set's value and keeps the value after adding,
/// because the next set is often the same or close: the same set again
/// is one tap, one fewer is two.
class AddSetRow extends StatefulWidget {
  /// Creates the row.
  const AddSetRow({
    super.key,
    required this.measuredIn,
    required this.startValue,
    required this.onAddSet,
  });

  /// Whether the exercise counts reps or seconds.
  final MeasuredIn measuredIn;

  /// The value to start with, usually the last set's.
  final int? startValue;

  /// Called with the reps (or seconds) of the set to add.
  final Future<void> Function(int value) onAddSet;

  @override
  State<AddSetRow> createState() => _AddSetRowState();
}

class _AddSetRowState extends State<AddSetRow> {
  late final TextEditingController _valueField = TextEditingController(
    text: widget.startValue == null ? '' : '${widget.startValue}',
  );
  String? _problem;
  bool _isSaving = false;

  @override
  void dispose() {
    _valueField.dispose();
    super.dispose();
  }

  /// Seconds go up and down in fives, reps in ones.
  int get _step => widget.measuredIn == MeasuredIn.reps ? 1 : 5;

  void _change(int by) {
    final value = int.tryParse(_valueField.text.trim()) ?? 0;
    final next = value + by < 0 ? 0 : value + by;
    setState(() {
      _valueField.text = '$next';
      _problem = null;
    });
  }

  Future<void> _add() async {
    final value = int.tryParse(_valueField.text.trim());
    if (value == null || value < 0) {
      setState(() => _problem = 'Enter the ${_unitWord()} as a whole number.');
      return;
    }
    setState(() {
      _problem = null;
      _isSaving = true;
    });
    // A light tick confirms the tap at once, before saving.
    HapticFeedback.selectionClick();
    await widget.onAddSet(value);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  String _unitWord() =>
      widget.measuredIn == MeasuredIn.reps ? 'reps' : 'seconds';

  @override
  Widget build(BuildContext context) {
    final label = widget.measuredIn == MeasuredIn.reps ? 'Reps' : 'Seconds';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Fewer $_step',
              onPressed: () => _change(-_step),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: Spacing.tight),
            SizedBox(
              // Room for the label "Seconds".
              width: 84,
              child: TextField(
                controller: _valueField,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: label),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: Spacing.tight),
            IconButton.outlined(
              tooltip: 'More $_step',
              onPressed: () => _change(_step),
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: Spacing.medium),
            // The button takes the rest of the row, so it ends at the
            // card's right edge and never pushes past it. Tonal: every
            // card has one, so a filled accent button in each would crowd
            // the screen.
            Expanded(
              child: FilledButton.tonal(
                onPressed: _isSaving ? null : _add,
                child: const Text(
                  'Add set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: ProblemText(_problem!),
          ),
      ],
    );
  }
}
