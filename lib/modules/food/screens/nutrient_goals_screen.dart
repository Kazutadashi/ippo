// SPDX-License-Identifier: GPL-3.0-or-later

/// The daily goals screen: your own amount a day for protein, carbs, fat
/// and the rest, in place of the reference amounts.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/section_card.dart';
import '../../body/body_actions.dart';
import '../../body/body_log.dart';
import '../daily_references.dart';
import '../nutrients.dart';

/// One field per nutrient in [goalNutrients]. An empty field means the
/// reference amount (shown as the hint) applies. A new goal counts from
/// today, like the calorie limit, so past days keep theirs.
class NutrientGoalsScreen extends StatefulWidget {
  /// Creates the screen.
  const NutrientGoalsScreen({super.key, required this.appState});

  /// The app-wide state, for reading and saving goals.
  final AppState appState;

  @override
  State<NutrientGoalsScreen> createState() => _NutrientGoalsScreenState();
}

class _NutrientGoalsScreenState extends State<NutrientGoalsScreen> {
  /// Today, the day new goals start.
  final String _date = formatDate(today());

  late final BodyLog _body = BodyLog.of(widget.appState);

  /// A field per nutrient, holding the user's goal or nothing.
  late final Map<String, TextEditingController> _fields = {
    for (final nutrient in goalNutrients)
      nutrient: TextEditingController(text: _ownGoalText(nutrient)),
  };

  final Map<String, String?> _problems = {};

  /// The user's goal for [nutrient] today as typed, or empty.
  String _ownGoalText(String nutrient) {
    final own = _body.nutrientTargetOn(nutrient, _date)?.amount;
    return own == null ? '' : formatAmount(own);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final problems = <String, String?>{};
    final changed = <String, double?>{};
    for (final nutrient in goalNutrients) {
      final text = _fields[nutrient]!.text.trim();
      final amount = text.isEmpty ? null : parsePositive(text);
      if (text.isNotEmpty && amount == null) {
        problems[nutrient] = 'Enter an amount above 0, or leave it empty.';
        continue;
      }
      if (text != _ownGoalText(nutrient)) {
        changed[nutrient] = amount;
      }
    }
    setState(
      () => _problems
        ..clear()
        ..addAll(problems),
    );
    if (problems.isNotEmpty) {
      return;
    }
    final actions = BodyActions(widget.appState);
    final saved = await saveOrShowError(context, () async {
      for (final entry in changed.entries) {
        await actions.setNutrientTarget(
          date: _date,
          nutrient: entry.key,
          amount: entry.value,
          kind: isLimitNutrient(entry.key) ? GoalKind.atMost : GoalKind.atLeast,
        );
      }
    });
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Everything the user can change here, for the discard guard.
  String _snapshot() =>
      [for (final field in _fields.values) field.text].join('\n');

  @override
  Widget build(BuildContext context) {
    // The reference amounts, without the user's own goals: the hints.
    final references = dailyReferences(
      energyTarget: _body.energyTargetOn(_date),
      weightKg: _body.weightAsOf(_date),
    );
    return DiscardGuard(
      snapshot: _snapshot,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close without saving',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Daily goals'),
          actions: [AppBarSaveButton(onPressed: _save)],
        ),
        body: ListView(
          padding: belowNavigationBar(
            context,
            const EdgeInsets.all(Spacing.screen),
          ),
          children: [
            const NoteText(
              'Your own amount a day for each nutrient. Leave a field '
              'empty to use the reference amount shown in it. A new goal '
              'counts from today; past days keep theirs.',
            ),
            const SizedBox(height: Spacing.medium),
            for (final nutrient in goalNutrients)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.medium),
                child: _goalField(nutrient, references[nutrient]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _goalField(String nutrient, double? reference) {
    final kind = nutrientKindOf(nutrient)!;
    final isLimit = isLimitNutrient(nutrient);
    return TextField(
      controller: _fields[nutrient],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: nutrient == goalNutrients.last
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: '${kind.label}, ${isLimit ? 'at most' : 'at least'}',
        // The reference amount, as a number: the unit is beside it.
        hintText: reference == null
            ? null
            : formatAmount(
                reference >= 10 ? reference.roundToDouble() : reference,
              ),
        suffixText: kind.unit,
        errorText: _problems[nutrient],
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
