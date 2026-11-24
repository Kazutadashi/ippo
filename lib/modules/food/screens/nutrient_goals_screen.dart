// SPDX-License-Identifier: GPL-3.0-or-later

/// The daily goals screen: the daily calorie limit, and your own amount
/// a day for protein, carbs, fat and the rest, in place of the reference
/// amounts. Every daily goal is set here.
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
import '../../body/bmr.dart';
import '../../body/screens/body_screen.dart';
import '../daily_references.dart';
import '../nutrients.dart';

/// The calorie limit, with what the body uses as a guide, then one field
/// per nutrient in [goalNutrients]. An empty field means the reference
/// amount (shown as the hint) applies. A new goal counts from today, so
/// past days keep theirs.
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

  /// The daily calorie limit, or nothing for none.
  late final TextEditingController _energyField = TextEditingController(
    text: _energyText,
  );

  final Map<String, String?> _problems = {};

  /// The calorie limit that applies today, as typed, or empty.
  String get _energyText {
    final limit = _body.energyTargetOn(_date);
    return limit == null ? '' : '${limit.round()}';
  }

  /// The user's goal for [nutrient] today as typed, or empty.
  String _ownGoalText(String nutrient) {
    final own = _body.nutrientTargetOn(nutrient, _date)?.amount;
    return own == null ? '' : formatAmount(own);
  }

  @override
  void dispose() {
    _energyField.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final problems = <String, String?>{};
    final changed = <String, double?>{};
    final energyText = _energyField.text.trim();
    final energy = energyText.isEmpty ? null : parsePositive(energyText);
    if (energyText.isNotEmpty && (energy == null || energy > 10000)) {
      problems[energyKey] = 'Enter a limit in kcal, or leave it empty.';
    }
    final energyChanged = energyText != _energyText;
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
      if (energyChanged) {
        await actions.setEnergyTarget(date: _date, energyKcal: energy);
      }
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
  String _snapshot() => [
    _energyField.text,
    for (final field in _fields.values) field.text,
  ].join('\n');

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
              'Leave a field empty to use the usual amount shown in it. A '
              'new goal counts from today; past days keep theirs.',
            ),
            const SizedBox(height: Spacing.small),
            _caloriesCard(context),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.restaurant, title: 'Nutrients'),
                const SizedBox(height: Spacing.small),
                for (final nutrient in goalNutrients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.medium),
                    child: _goalField(nutrient, references[nutrient]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The calorie limit, and what the body uses a day as a guide to
  /// choosing it, worked out on the Body and calories screen.
  Widget _caloriesCard(BuildContext context) {
    final birthYear = _body.birthYear;
    final bmr = basalMetabolicRate(
      sex: _body.sex,
      weightKg: _body.weightAsOf(_date),
      heightCm: _body.heightCm,
      ageYears: birthYear == null ? null : DateTime.now().year - birthYear,
    );
    String kcal(double value) => '${formatThousands(value.round())} kcal';
    return SectionCard(
      children: [
        CardHeader(
          icon: Icons.local_fire_department,
          title: 'Calories',
          action: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => BodyScreen(appState: widget.appState),
              ),
            ),
            child: const Text('Body details'),
          ),
        ),
        const SizedBox(height: Spacing.small),
        TextField(
          controller: _energyField,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Daily limit, at most',
            hintText: '2000',
            suffixText: 'kcal',
            errorText: _problems[energyKey],
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.small),
        NoteText(
          bmr == null
              ? 'Fill in your body details to see how much energy you use '
                    'in a day. The limit also sets the usual amounts of fat, '
                    'carbs and sugars.'
              : 'You use about ${kcal(bmr)} a day at rest, and '
                    '${kcal(bmr * ActivityLevel.sedentary.factor)} to '
                    '${kcal(bmr * ActivityLevel.active.factor)} with '
                    'everyday activity. To lose weight slowly, eat about 300 '
                    'to 500 kcal less.',
        ),
      ],
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
