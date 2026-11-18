// SPDX-License-Identifier: GPL-3.0-or-later

/// A row for logging sets straight from a card: `[20] reps × [2] sets Add`.
library;

import 'package:material_ui/material_ui.dart';

import '../exercise.dart';

/// The most sets that can be added in one go. A typo such as 22 instead
/// of 2 should not flood the log.
const int maximumSetsAtOnce = 10;

/// Lets the user type reps (or seconds) and a number of sets, and add
/// them with one tap.
///
/// The typed reps stay after adding, because the next set is often the
/// same or close. The number of sets goes back to 1.
class QuickSetRow extends StatefulWidget {
  /// Creates the row.
  const QuickSetRow({
    super.key,
    required this.measuredIn,
    required this.startValue,
    required this.onAddSets,
  });

  /// Whether the exercise counts reps or seconds.
  final MeasuredIn measuredIn;

  /// The value to start with, usually the last set's.
  final int? startValue;

  /// Called with the reps (or seconds) and how many sets to add.
  final Future<void> Function(int value, int setCount) onAddSets;

  @override
  State<QuickSetRow> createState() => _QuickSetRowState();
}

class _QuickSetRowState extends State<QuickSetRow> {
  late final TextEditingController _valueField = TextEditingController(
    text: widget.startValue == null ? '' : '${widget.startValue}',
  );
  final TextEditingController _setCountField = TextEditingController(text: '1');
  String? _problem;
  bool _isSaving = false;

  @override
  void dispose() {
    _valueField.dispose();
    _setCountField.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = int.tryParse(_valueField.text.trim());
    final setCount = int.tryParse(_setCountField.text.trim());
    if (value == null || value < 0) {
      setState(() => _problem = 'Enter the ${_unitWord()} as a whole number.');
      return;
    }
    if (setCount == null || setCount < 1 || setCount > maximumSetsAtOnce) {
      setState(
        () => _problem = 'Enter 1 to $maximumSetsAtOnce sets at a time.',
      );
      return;
    }
    setState(() {
      _problem = null;
      _isSaving = true;
    });
    await widget.onAddSets(value, setCount);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _setCountField.text = '1';
      });
    }
  }

  String _unitWord() =>
      widget.measuredIn == MeasuredIn.reps ? 'reps' : 'seconds';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _valueField,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.measuredIn == MeasuredIn.reps
                      ? 'Reps'
                      : 'Seconds',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text('×'),
            ),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _setCountField,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sets'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _isSaving ? null : _add,
              child: const Text('Add'),
            ),
          ],
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _problem!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
