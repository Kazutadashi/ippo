// SPDX-License-Identifier: GPL-3.0-or-later

/// A window for pasting a nutrition label's text.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../nutrition_label.dart';

/// An example of the simple format, shown in the window and copied by
/// its "Copy the format" button. See `docs/food-labels.md`.
const String labelFormatExample = '''
name: Potato chips
serving: 9 chips = 28 g
calories: 150
fat: 9 g
saturated fat: 1.5 g
carbohydrates: 15 g
sugars: 1 g
fiber: 1 g
protein: 2 g
salt: 0.4 g''';

/// Asks for a label's text and reads it. Closes with the reading, or
/// with nothing if cancelled.
class LabelPasteDialog extends StatefulWidget {
  /// Creates the window.
  const LabelPasteDialog({super.key});

  @override
  State<LabelPasteDialog> createState() => _LabelPasteDialogState();
}

class _LabelPasteDialogState extends State<LabelPasteDialog> {
  final TextEditingController _textField = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _textField.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) {
      setState(() => _textField.text = text);
    }
  }

  Future<void> _copyFormat() async {
    await Clipboard.setData(const ClipboardData(text: labelFormatExample));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('The format was copied.')));
    }
  }

  void _fillIn() {
    final reading = readNutritionLabel(_textField.text);
    if (reading.isEmpty) {
      setState(
        () =>
            _problem = 'No serving size or nutrients were found in this text.',
      );
      return;
    }
    Navigator.of(context).pop(reading);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fill in from label'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoteText(
            'Paste the text of a nutrition label, or type it. To use a '
            'photo, ask an assistant to write the label in this format:',
          ),
          const SizedBox(height: 8),
          SelectableText(
            labelFormatExample,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontFamily: 'monospace'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 48),
              ),
              onPressed: _copyFormat,
              icon: const Icon(Icons.copy),
              label: const Text('Copy the format'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textField,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: 'Label text',
              alignLabelWithHint: true,
              errorText: _problem,
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste),
                onPressed: _pasteFromClipboard,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _fillIn, child: const Text('Fill in')),
      ],
    );
  }
}
