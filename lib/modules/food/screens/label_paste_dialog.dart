// SPDX-License-Identifier: GPL-3.0-or-later

/// A window for pasting a nutrition label's text.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../nutrition_label.dart';

/// An example of the simple format, copied by "Copy the format" for
/// asking an assistant to read a photo. See `docs/food-labels.md`.
const String labelFormatExample = '''
name: Potato chips
serving: 9 chips = 28 g
calories: 150
fat: 9 g
carbohydrates: 15 g
protein: 2 g
vitamin d: 2 mcg
calcium: 20 mg

ingredients: Potatoes, sunflower oil, salt.''';

/// Asks for a label's text and reads it. Closes with the reading, or
/// with nothing if cancelled.
///
/// It is mostly one big text box. Help for using a photo is one tap
/// away, behind "Using a photo?".
class LabelPasteDialog extends StatefulWidget {
  /// Creates the window.
  const LabelPasteDialog({super.key});

  @override
  State<LabelPasteDialog> createState() => _LabelPasteDialogState();
}

class _LabelPasteDialogState extends State<LabelPasteDialog> {
  final TextEditingController _textField = TextEditingController();
  String? _problem;
  bool _isShowingPhotoHelp = false;

  @override
  void dispose() {
    _textField.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) {
      setState(() {
        _textField.text = text;
        _problem = null;
      });
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
      setState(() => _problem = 'No nutrition values found in this text.');
      return;
    }
    Navigator.of(context).pop(reading);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste nutrition label'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textField,
            autofocus: true,
            minLines: 8,
            maxLines: 14,
            decoration: InputDecoration(
              hintText: 'Serving size 9 chips (28g)\nCalories 150\n…',
              errorText: _problem,
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste),
                onPressed: _pasteFromClipboard,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () =>
                  setState(() => _isShowingPhotoHelp = !_isShowingPhotoHelp),
              icon: Icon(
                _isShowingPhotoHelp ? Icons.expand_less : Icons.expand_more,
              ),
              label: const Text('Using a photo?'),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _isShowingPhotoHelp
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const NoteText(
                        'Ask an assistant to write the label in this '
                        'format, then paste its answer above.',
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
                    ],
                  )
                : const SizedBox(width: double.infinity),
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
