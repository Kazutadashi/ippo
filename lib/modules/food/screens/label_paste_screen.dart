// SPDX-License-Identifier: GPL-3.0-or-later

/// The screen for filling in a food from a pasted nutrition label.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/number_input.dart';
import '../food_serving.dart';
import '../label_json.dart';
import '../nutrients.dart';
import '../nutrition_label.dart';

/// A short example of the JSON, shown in the empty box so it is clear
/// what to paste.
const String _jsonHint = '''{
  "name": "Potato chips",
  "per": "serving",
  "serving": {"unit": "chips", "count": 9, "amount": 28},
  "nutrients": {"energy_kcal": 150, "fat_g": 9, …}
}''';

/// Takes a label's JSON or text, shows what was read from it as it is
/// typed or pasted, and closes with the reading when the person taps
/// "Fill in" (or with nothing when closed).
///
/// How to get a label into JSON is explained behind the ⓘ button, so
/// the screen itself stays short: a Paste button, the box, and what
/// was found.
class LabelPasteScreen extends StatefulWidget {
  /// Creates the screen.
  const LabelPasteScreen({super.key});

  @override
  State<LabelPasteScreen> createState() => _LabelPasteScreenState();
}

class _LabelPasteScreenState extends State<LabelPasteScreen> {
  final TextEditingController _textField = TextEditingController();

  /// What the box's text reads as, updated as it changes.
  LabelReading? _reading;

  @override
  void dispose() {
    _textField.dispose();
    super.dispose();
  }

  void _read() {
    final text = _textField.text;
    setState(() {
      _reading = text.trim().isEmpty ? null : readNutritionLabel(text);
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) {
      return;
    }
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no text to paste.')),
      );
      return;
    }
    _textField.text = text;
    _read();
  }

  void _clear() {
    _textField.clear();
    _read();
  }

  Future<void> _copyFormat() async {
    await Clipboard.setData(ClipboardData(text: labelJsonPrompt()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied: instructions for the JSON format.'),
        ),
      );
    }
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => const _HowToDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = _reading;
    final canFillIn = reading != null && !reading.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill in from a label'),
        actions: [
          IconButton(
            tooltip: 'How this works',
            icon: const Icon(Icons.info_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyFormat,
                  icon: const Icon(Icons.data_object),
                  label: const Text('Copy the format'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textField,
            minLines: 7,
            maxLines: 14,
            onChanged: (_) => _read(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              labelText: 'Label as JSON or text',
              alignLabelWithHint: true,
              hintText: _jsonHint,
              hintMaxLines: 8,
              suffixIcon: _textField.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: _clear,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (reading != null) _FoundList(reading: reading),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: canFillIn
                ? () => Navigator.of(context).pop(reading)
                : null,
            child: Text(
              canFillIn
                  ? 'Fill in ${_countOf(reading)} '
                        '${_countOf(reading) == 1 ? 'value' : 'values'}'
                  : 'Fill in',
            ),
          ),
        ),
      ),
    );
  }
}

/// How many values [reading] will fill in: as the food form counts them.
int _countOf(LabelReading reading) {
  return reading.nutrients.length +
      (reading.name == null ? 0 : 1) +
      (reading.serving == null ? 0 : 1) +
      (reading.ingredients == null ? 0 : 1);
}

/// What was read, as a list of label and value, so the person can see
/// before filling in whether the paste worked.
class _FoundList extends StatelessWidget {
  const _FoundList({required this.reading});

  final LabelReading reading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (reading.isEmpty) {
      return Text(
        'Nothing found yet. Check that it is a nutrition label, or tap ⓘ '
        'to see what works.',
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
      );
    }
    final unit = reading.measuredIn;
    final serving = reading.serving;
    final name = reading.name;
    final ingredients = reading.ingredients;
    final rows = <(String, String)>[
      if (name != null) ('Name', name),
      if (serving != null)
        (
          'Serving',
          '${writeServingText(serving)} = ${formatAmount(serving.amount)} $unit',
        ),
      ('Values are per', reading.isPer100 ? '100 $unit' : 'serving'),
      for (final key in orderedNutrientKeys(reading.nutrients.keys))
        (nutrientKindOf(key)!.label, _valueText(key, reading.nutrients[key]!)),
      if (ingredients != null) ('Ingredients', ingredients),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FOUND',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (!reading.isPer100 && serving == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'The values are per serving, but no serving size was found. '
              'You can add it after filling in.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
            ),
          ),
        if (reading.unusedNames.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Not used (unknown names): ${reading.unusedNames.join(', ')}',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
            ),
          ),
      ],
    );
  }
}

/// A nutrient's value with its unit: `150 kcal`, `1.5 g`.
String _valueText(String key, double value) {
  if (key == energyKey) {
    return formatEnergy(value);
  }
  return '${formatAmount(value)} ${nutrientKindOf(key)!.unit}';
}

/// The ⓘ help: how to get a label's values into the box.
class _HowToDialog extends StatelessWidget {
  const _HowToDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(String number, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solid accent with dark numerals: readable, unlike the pale
          // default.
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: Text(
              number,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return AlertDialog(
      title: const Text('Filling in from a label'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ippo never goes online, so it cannot read a photo itself. '
            'An AI assistant can, and can write the label as JSON:',
          ),
          const SizedBox(height: 12),
          step('1', 'Take a photo of the nutrition label.'),
          step(
            '2',
            'Tap "Copy the format", then send the photo and the copied '
                'instructions to an AI assistant (such as Claude).',
          ),
          step('3', 'Copy its answer, then tap "Paste" here.'),
          step(
            '4',
            'Check what was found under the box, then tap "Fill in". You '
                'can still change anything before saving the food.',
          ),
          const Divider(height: 24),
          Text('Other ways', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text(
            'Plain label text works too: copy it from a shop\'s website or '
            'a food database, or type it, one value per line ("Calories '
            '150", "Fat 9 g", "Per 100 g"). JSON copied from a food in '
            'another Ippo data folder also works.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
