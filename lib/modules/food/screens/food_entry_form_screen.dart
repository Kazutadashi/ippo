// SPDX-License-Identifier: GPL-3.0-or-later

/// Logging an amount of a food, or changing such an entry.
library;

import 'package:material_ui/material_ui.dart';

import '../daily_references.dart';

import '../../body/body_log.dart';

import '../../../core/app_state.dart';
import '../../../core/clock_time.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/time_fields.dart';
import '../food.dart';
import '../food_actions.dart';
import '../food_diary.dart';
import '../food_entry.dart';
import '../nutrients.dart';
import 'food_form_screen.dart';
import 'nutrient_summary.dart';

/// The form for an entry made from a food: the amount.
///
/// Closes with `true` when something was saved or deleted.
class FoodEntryFormScreen extends StatefulWidget {
  /// Creates the form for logging [food] on [date].
  const FoodEntryFormScreen.add({
    super.key,
    required this.appState,
    required Food this.food,
    required String this.date,
    required this.isToday,
  }) : entry = null;

  /// Creates the form for changing [entry].
  const FoodEntryFormScreen.edit({
    super.key,
    required this.appState,
    required FoodEntry this.entry,
  }) : food = null,
       date = null,
       isToday = false;

  /// The app-wide state.
  final AppState appState;

  /// The food to log, when adding.
  final Food? food;

  /// The day to log on (`YYYY-MM-DD`), when adding.
  final String? date;

  /// Whether [date] is today, so the time starts at now.
  final bool isToday;

  /// The entry to change, when editing.
  final FoodEntry? entry;

  @override
  State<FoodEntryFormScreen> createState() => _FoodEntryFormScreenState();
}

class _FoodEntryFormScreenState extends State<FoodEntryFormScreen> {
  /// Whether the amount is typed in pieces ("9 chips") rather than grams.
  /// Pieces are the default when the food has a serving size.
  late bool _inPieces =
      _pieceName != null &&
      (widget.entry == null || widget.entry!.unitCount != null);

  late final TextEditingController _amountField = TextEditingController(
    text: _startingAmountText(),
  );
  String? _amountProblem;

  /// When it was eaten: now for a new entry today, "Not set" for another
  /// day (the time is not known), or the entry's own time.
  late ClockTime? _time = startingEntryTime(
    entryTime: widget.entry?.time,
    isNew: widget.entry == null,
    isToday: widget.isToday,
  );

  @override
  void initState() {
    super.initState();
    // The guessed amount is selected, so typing replaces it.
    _amountField.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amountField.text.length,
    );
  }

  @override
  void dispose() {
    _amountField.dispose();
    super.dispose();
  }

  String get _name => widget.food?.name ?? widget.entry!.name;

  /// `g` or `ml`.
  String get _unit => widget.food?.measuredIn ?? widget.entry!.measuredIn ?? '';

  /// The name of one piece, such as `chips`, if the amount can be typed
  /// in pieces. Comes from the food's serving size, or, when changing an
  /// entry, from how it was entered.
  String? get _pieceName {
    final entry = widget.entry;
    if (entry != null) {
      return entry.amountPerUnit == null ? null : entry.unitName;
    }
    return widget.food?.serving?.unit;
  }

  /// The grams (or ml) in one piece, if known.
  double? get _amountPerPiece =>
      widget.entry?.amountPerUnit ?? widget.food?.serving?.amountPerUnit;

  String _startingAmountText() {
    if (widget.entry == null) {
      return _guessedAmountText();
    }
    final entry = widget.entry!;
    final pieces = entry.unitCount;
    if (_inPieces && pieces != null) {
      return formatAmount(pieces);
    }
    final amount = entry.amount;
    return amount == null ? '' : formatAmount(amount);
  }

  /// A first guess for a new entry, in the unit the form starts in: the
  /// amount logged last time, or else one serving.
  String _guessedAmountText() {
    final food = widget.food!;
    final last = FoodDiary.of(widget.appState).lastEntryOf(food.id);
    final grams = last?.amount ?? food.serving?.amount;
    if (grams == null) {
      return '';
    }
    final perPiece = _amountPerPiece;
    if (_inPieces && perPiece != null) {
      return formatAmount(last?.unitCount ?? grams / perPiece);
    }
    return formatAmount(grams);
  }

  /// The typed amount turned into grams (or ml), or null if nothing
  /// sensible is typed.
  double? _typedGrams() {
    final typed = parseAmount(_amountField.text);
    if (typed == null) {
      return null;
    }
    final perPiece = _amountPerPiece;
    return _inPieces && perPiece != null ? typed * perPiece : typed;
  }

  /// Switches between pieces and grams, converting what is typed.
  void _switchUnit(bool toPieces) {
    final perPiece = _amountPerPiece;
    final typed = parseAmount(_amountField.text);
    setState(() {
      if (typed != null && perPiece != null && toPieces != _inPieces) {
        final converted = toPieces ? typed / perPiece : typed * perPiece;
        _amountField.text = formatAmount(converted);
      }
      _inPieces = toPieces;
    });
  }

  /// The nutrients for [amount] grams, for the live preview.
  Nutrients _nutrientsFor(double amount) {
    final food = widget.food;
    if (food != null) {
      return food.nutrientsFor(amount);
    }
    // Editing: scale the entry's own copy, as FoodActions will.
    final entry = widget.entry!;
    final oldAmount = entry.amount ?? 0;
    return oldAmount == 0
        ? entry.nutrients
        : entry.nutrients.scaledBy(amount / oldAmount);
  }

  /// The other unit, worked out from what is typed: "= 28 g" or
  /// "≈ 12.9 chips".
  String? _conversionNote(double grams) {
    final perPiece = _amountPerPiece;
    final pieceName = _pieceName;
    if (perPiece == null || pieceName == null || grams == 0) {
      return null;
    }
    if (_inPieces) {
      return '= ${formatAmount(grams)} $_unit';
    }
    return '≈ ${formatAmount(grams / perPiece)} $pieceName';
  }

  Future<void> _save() async {
    final grams = _typedGrams();
    if (grams == null || grams == 0) {
      setState(() => _amountProblem = 'Please enter an amount above 0.');
      return;
    }
    final pieces = _inPieces ? parseAmount(_amountField.text) : null;
    final actions = FoodActions(widget.appState);
    final food = widget.food;
    final entry = widget.entry;
    final saved = await saveOrShowError(context, () {
      if (food != null) {
        return actions.recordFoodEntry(
          date: widget.date!,
          time: _time?.toString(),
          food: food,
          amount: grams,
          unitCount: pieces,
          unitName: pieces == null ? null : _pieceName,
        );
      }
      return actions.changeFoodEntryAmount(
        entry!,
        newAmount: grams,
        unitCount: pieces,
        time: _time?.toString(),
      );
    });
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _editFood() {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (context) =>
            FoodFormScreen.edit(appState: widget.appState, food: widget.food!),
      ),
    );
  }

  Future<void> _delete() async {
    final entry = widget.entry!;
    final actions = FoodActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteEntry(entry.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    showUndoMessage(
      messenger,
      message: 'Deleted ${entry.name}.',
      onUndo: () => actions.restoreEntry(entry.id),
    );
  }

  /// Everything the user can change here, for the discard guard.
  String _snapshot() => [_amountField.text, _inPieces, _time].join('\n');

  @override
  Widget build(BuildContext context) {
    final grams = _typedGrams() ?? 0;
    final pieceName = _pieceName;
    final conversion = _conversionNote(grams);
    final serving = widget.food?.serving;
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
          title: Text(_name),
          actions: [AppBarSaveButton(onPressed: _save)],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pieceName != null) ...[
              const FieldLabel('Amount in'),
              SegmentedButton<bool>(
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(value: true, label: Text(pieceName)),
                  ButtonSegment(value: false, label: Text(_unit)),
                ],
                selected: {_inPieces},
                showSelectedIcon: false,
                onSelectionChanged: (choice) => _switchUnit(choice.single),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _amountField,
              autofocus: widget.entry == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: _inPieces ? pieceName : _unit,
                helperText: serving == null
                    ? null
                    : 'One serving is ${serving.describe(_unit)}.',
                errorText: _amountProblem,
              ),
              // Redraw so the preview below follows the typed amount.
              onChanged: (_) => setState(() => _amountProblem = null),
              onSubmitted: (_) => _save(),
            ),
            if (conversion != null) ...[
              const SizedBox(height: 8),
              NoteText(conversion),
            ],
            const SizedBox(height: 16),
            TimeField(
              label: 'Eaten at',
              time: _time,
              onChanged: (time) => setState(() => _time = time),
            ),
            const SizedBox(height: 16),
            // This amount against a whole day's normal amounts.
            NutrientInfoRow(
              nutrients: _nutrientsFor(grams),
              references: dailyReferencesOn(
                BodyLog.of(widget.appState),
                widget.entry?.date ?? widget.date ?? formatDate(today()),
              ),
            ),
            if (widget.entry != null)
              DeleteButton(label: 'Delete this entry', onPressed: _delete),
            // Changing the food itself (its name or label values) starts
            // here, where the food is already open.
            if (widget.food != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _editFood,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit this food'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The time a food entry form starts with: the entry's own time when
/// changing one, now for a new entry today, and "Not set" (null) for a
/// new entry on another day, whose time is not known.
ClockTime? startingEntryTime({
  required String? entryTime,
  required bool isNew,
  required bool isToday,
}) {
  if (!isNew) {
    return entryTime == null || !isValidTimeOfDay(entryTime)
        ? null
        : ClockTime(
            int.parse(entryTime.substring(0, 2)),
            int.parse(entryTime.substring(3, 5)),
          );
  }
  if (!isToday) {
    return null;
  }
  final now = DateTime.now();
  return ClockTime(now.hour, now.minute);
}
