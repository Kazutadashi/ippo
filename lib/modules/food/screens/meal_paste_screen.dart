// SPDX-License-Identifier: GPL-3.0-or-later

/// Logging a whole meal at once from pasted JSON: new foods are added to
/// the list, and every food gets an entry with the amount eaten.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/clock_time.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/time_fields.dart';
import '../food_actions.dart';
import '../food_diary.dart';
import '../meal_json.dart';
import '../nutrients.dart';
import 'food_entry_form_screen.dart';

/// Paste a meal written as JSON (see `meal_json.dart`), check what was
/// read, and log it on a day and time. Closes with `true` once logged.
class MealPasteScreen extends StatefulWidget {
  /// Creates the screen for logging on [date] (`YYYY-MM-DD`); [isToday]
  /// decides whether the time starts at now.
  const MealPasteScreen({
    super.key,
    required this.appState,
    required this.date,
    required this.isToday,
  });

  /// The app-wide state.
  final AppState appState;

  /// The day the meal is logged on, unless changed here.
  final String date;

  /// Whether [date] is today.
  final bool isToday;

  @override
  State<MealPasteScreen> createState() => _MealPasteScreenState();
}

class _MealPasteScreenState extends State<MealPasteScreen> {
  final TextEditingController _textField = TextEditingController();

  /// What the box's text reads as, or null if it is not a meal.
  MealReading? _meal;

  late DateTime _day = parseDate(widget.date)!;

  /// When it was eaten: now for today, else not known, unless the pasted
  /// meal says.
  late ClockTime? _time = startingEntryTime(
    entryTime: null,
    isNew: true,
    isToday: widget.isToday,
  );

  @override
  void dispose() {
    _textField.dispose();
    super.dispose();
  }

  void _read() {
    final text = _textField.text;
    final meal = text.trim().isEmpty ? null : readMealJson(text);
    setState(() {
      _meal = meal;
      // A time in the paste is taken over; the field can still change it.
      if (meal?.time != null) {
        _time = meal!.time;
      }
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

  Future<void> _copyFormat() async {
    await Clipboard.setData(ClipboardData(text: mealJsonPrompt()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied: instructions for a meal.')),
      );
    }
  }

  Future<void> _log(MealReading meal) async {
    final messenger = ScaffoldMessenger.of(context);
    var added = 0;
    final saved = await saveOrShowError(context, () async {
      added = await FoodActions(widget.appState).logMeal(
        date: formatDate(_day),
        time: _time?.toString(),
        items: meal.items,
      );
    });
    if (!saved || !mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    final count = meal.items.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Logged $count ${count == 1 ? 'food' : 'foods'}'
          '${added == 0 ? '' : ', $added new in your foods'}.',
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(context: context, builder: (context) => const _HowTo());
  }

  @override
  Widget build(BuildContext context) {
    final meal = _meal;
    final canLog = meal != null && meal.items.isNotEmpty;
    final text = _textField.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paste a meal'),
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
              const SizedBox(width: Spacing.small),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyFormat,
                  icon: const Icon(Icons.data_object),
                  label: const Text('Copy the format'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.medium),
          TextField(
            controller: _textField,
            minLines: 5,
            maxLines: 10,
            onChanged: (_) => _read(),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Meal as JSON',
              alignLabelWithHint: true,
              hintText:
                  'Tap "Copy the format", send it to an AI assistant with '
                  'photos of the labels and how much you ate, then paste '
                  'its answer here.',
              hintMaxLines: 4,
              suffixIcon: text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _textField.clear();
                        _read();
                      },
                    ),
            ),
          ),
          if (text.isNotEmpty && meal == null) ...[
            const SizedBox(height: Spacing.small),
            const ProblemText(
              'This is not a meal in the copied format. Ask the assistant '
              'for the format again, or check the JSON is complete.',
            ),
          ],
          if (meal != null) ...[
            _FoundCard(appState: widget.appState, meal: meal),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.schedule, title: 'When'),
                DayAndTimeFields(
                  day: _day,
                  time: _time,
                  onDayChanged: (day) => setState(() => _day = day),
                  onTimeChanged: (time) => setState(() => _time = time),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: canLog ? () => _log(meal) : null,
            child: Text(
              canLog
                  ? 'Log ${meal.items.length} '
                        '${meal.items.length == 1 ? 'food' : 'foods'}'
                  : 'Log the meal',
            ),
          ),
        ),
      ),
    );
  }
}

/// What was read: each food with the amount eaten and its energy, marked
/// "New" when it will be added to the foods, and below them anything that
/// could not be read, with the reason.
class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.appState, required this.meal});

  final AppState appState;
  final MealReading meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final diary = FoodDiary.of(appState);
    // The energy that will be logged: a food already in the list is
    // logged with its own values, not the pasted ones.
    double energyOf(MealItem item) {
      final known = diary.foodNamed(item.name);
      return known == null
          ? item.eaten.energyKcal
          : known.nutrientsFor(item.amount).energyKcal;
    }

    var total = 0.0;
    for (final item in meal.items) {
      total += energyOf(item);
    }
    return SectionCard(
      children: [
        CardHeader(
          icon: Icons.restaurant,
          title: meal.items.isEmpty ? 'Nothing to log' : 'Foods',
        ),
        for (final item in meal.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text(
              diary.foodNamed(item.name) == null
                  ? '${formatAmount(item.amount)} ${item.measuredIn}    '
                        'New in your foods'
                  : '${formatAmount(item.amount)} ${item.measuredIn}    '
                        'Already in your foods',
              style: TextStyle(color: muted),
            ),
            trailing: Text(
              formatEnergy(energyOf(item)),
              style: theme.textTheme.titleSmall,
            ),
          ),
        if (meal.items.length > 1) ...[
          const Divider(height: Spacing.small),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.small),
            child: Row(
              children: [
                Expanded(
                  child: Text('Total', style: theme.textTheme.titleSmall),
                ),
                Text(formatEnergy(total), style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
        for (final problem in meal.problems)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.tight),
            child: ProblemText('Not logged: $problem'),
          ),
        if (meal.items.any((item) => diary.foodNamed(item.name) != null))
          const Padding(
            padding: EdgeInsets.only(top: Spacing.small),
            child: NoteText(
              'A food already in your foods keeps its own values; only '
              'the amount eaten is logged.',
            ),
          ),
      ],
    );
  }
}

/// How pasting a meal works, step by step.
class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pasting a meal'),
      scrollable: true,
      content: const Text(
        'Ippo never goes online, so it cannot read photos itself. An AI '
        'assistant can, and the photos go only where you send them.\n\n'
        '1. Take a photo of each food\'s nutrition label.\n'
        '2. Tap "Copy the format".\n'
        '3. Send the assistant the photos, the copied text, and how much '
        'you ate of each, such as "39 g ham, 76 g cheese".\n'
        '4. Copy its answer and tap "Paste".\n'
        '5. Check the foods and the time, then tap "Log".\n\n'
        'New foods are added to your foods, so next time you can pick '
        'them from the list. Foods you already have keep their values.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
