// SPDX-License-Identifier: GPL-3.0-or-later

/// The screen for body details, weight, and the daily calorie limit.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/units.dart';
import '../../../core/widgets/section_card.dart';
import '../body_actions.dart';
import '../body_log.dart';
import '../bmr.dart';
import 'sources_screen.dart';

/// Three cards, top to bottom: about you (sex, year of birth, height);
/// your weight today, with the last few weighings; and the daily
/// calories: the BMR worked out from them, the energy used in a day at
/// each activity level, and the limit you set.
class BodyScreen extends StatelessWidget {
  /// Creates the screen.
  const BodyScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body and calories')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final log = BodyLog.of(appState);
          final date = formatDate(today());
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              _ProfileCard(appState: appState, log: log),
              _WeightCard(appState: appState, log: log, date: date),
              _CaloriesCard(appState: appState, log: log, date: date),
            ],
          );
        },
      ),
    );
  }
}

/// An ⓘ that opens how the numbers are worked out, with sources.
class _SourcesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'How these are worked out',
      icon: const Icon(Icons.info_outline),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const SourcesScreen()),
      ),
    );
  }
}

/// Reads a positive number typed in [field], or null.
double? _positive(TextEditingController field) {
  final value = double.tryParse(field.text.trim().replaceAll(',', '.'));
  return value == null || value <= 0 ? null : value;
}

/// Sex, year of birth and height: set once, changed rarely.
class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.appState, required this.log});

  final AppState appState;
  final BodyLog log;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late Sex? _sex = widget.log.sex;
  late final TextEditingController _birthYear = TextEditingController(
    text: widget.log.birthYear?.toString() ?? '',
  );
  // Height in cm, or in feet and inches with imperial units.
  late final TextEditingController _height = TextEditingController(
    text: widget.log.heightCm == null ? '' : formatAmount(widget.log.heightCm!),
  );
  late final TextEditingController _feet = TextEditingController(
    text: widget.log.heightCm == null
        ? ''
        : '${feetAndInches(widget.log.heightCm!).$1}',
  );
  late final TextEditingController _inches = TextEditingController(
    text: widget.log.heightCm == null
        ? ''
        : '${feetAndInches(widget.log.heightCm!).$2}',
  );
  String? _problem;

  @override
  void dispose() {
    _birthYear.dispose();
    _height.dispose();
    _feet.dispose();
    _inches.dispose();
    super.dispose();
  }

  /// The height typed in feet and inches, in centimetres, or null.
  double? _imperialHeight() {
    final feet = int.tryParse(_feet.text.trim()) ?? 0;
    final inches =
        double.tryParse(_inches.text.trim().replaceAll(',', '.')) ?? 0;
    if (feet <= 0 && inches <= 0) {
      return null;
    }
    return centimetresFrom(feet, inches);
  }

  /// A number field with a [label] and a [unit] after the number.
  Widget _number(TextEditingController field, String label, String unit) {
    return TextField(
      controller: field,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, suffixText: unit),
    );
  }

  Future<void> _save() async {
    final sex = _sex;
    final year = int.tryParse(_birthYear.text.trim());
    final height = showImperialUnits ? _imperialHeight() : _positive(_height);
    final thisYear = DateTime.now().year;
    if (sex == null ||
        year == null ||
        year < 1900 ||
        year > thisYear ||
        height == null ||
        height > 300) {
      setState(
        () =>
            _problem = 'Choose a sex, and enter a year of birth and a height.',
      );
      return;
    }
    setState(() => _problem = null);
    HapticFeedback.selectionClick();
    await saveOrShowError(
      context,
      () =>
          BodyActions(widget.appState)
              .saveProfile(sex: sex, birthYear: year, heightCm: height),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        CardHeader(
          icon: Icons.person_outline,
          title: 'About you',
          action: _SourcesButton(),
        ),
        const FieldLabel('Sex'),
        SegmentedButton<Sex>(
          expandedInsets: EdgeInsets.zero,
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: Sex.female, label: Text('Female')),
            ButtonSegment(value: Sex.male, label: Text('Male')),
          ],
          selected: _sex == null ? const {} : {_sex!},
          showSelectedIcon: false,
          onSelectionChanged: (choice) =>
              setState(() => _sex = choice.isEmpty ? null : choice.single),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _birthYear,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Year of birth'),
              ),
            ),
            const SizedBox(width: 12),
            if (showImperialUnits) ...[
              Expanded(child: _number(_feet, 'Height', 'ft')),
              const SizedBox(width: 12),
              Expanded(child: _number(_inches, '', 'in')),
            ] else
              Expanded(child: _number(_height, 'Height', 'cm')),
          ],
        ),
        if (_problem != null) ...[
          const SizedBox(height: 8),
          ProblemText(_problem!),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Today's weight, and the last few weighings.
class _WeightCard extends StatefulWidget {
  const _WeightCard({
    required this.appState,
    required this.log,
    required this.date,
  });

  final AppState appState;
  final BodyLog log;
  final String date;

  @override
  State<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<_WeightCard> {
  late final TextEditingController _weight = TextEditingController(
    text: _todaysText,
  );
  String? _problem;

  /// Today's weight as typed: in kg, or in lb with imperial units.
  String get _todaysText {
    final today = widget.log.weightOn(widget.date);
    return today == null
        ? ''
        : formatAmount(roundToTenth(weightInShownUnit(today.weightKg)));
  }

  @override
  void didUpdateWidget(_WeightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.weightOn(widget.date)?.weightKg !=
        widget.log.weightOn(widget.date)?.weightKg) {
      _weight.text = _todaysText;
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shown = _positive(_weight);
    final weight = shown == null ? null : kilogramsFromShown(shown);
    if (weight == null || weight > 500) {
      setState(() => _problem = 'Enter your weight in $weightUnit.');
      return;
    }
    setState(() => _problem = null);
    HapticFeedback.selectionClick();
    await saveOrShowError(
      context,
      () => BodyActions(widget.appState).saveWeight(
        date: widget.date,
        weightKg: weight,
        existing: widget.log.weightOn(widget.date),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = [
      for (final weight in widget.log.weights.reversed)
        if (!weight.isDeleted) weight,
    ].take(5).toList();
    final isSaved = _weight.text.trim() == _todaysText;
    return SectionCard(
      children: [
        const CardHeader(icon: Icons.monitor_weight_outlined, title: 'Weight'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Today',
                  suffixText: weightUnit,
                  errorText: _problem,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: Spacing.small),
            FilledButton.tonal(
              onPressed: isSaved ? null : _save,
              child: Text(isSaved && _todaysText.isNotEmpty ? 'Saved' : 'Save'),
            ),
          ],
        ),
        for (final weight in recent)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    describeDayOf(weight.date),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatWeight(weight.weightKg),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A date (`YYYY-MM-DD`) as on screen, such as "Mon 16 Nov".
String describeDayOf(String date) {
  final day = parseDate(date);
  return day == null ? date : formatShortDate(day);
}

/// The BMR, the energy used in a day at each activity level, and the
/// daily limit.
class _CaloriesCard extends StatefulWidget {
  const _CaloriesCard({
    required this.appState,
    required this.log,
    required this.date,
  });

  final AppState appState;
  final BodyLog log;
  final String date;

  @override
  State<_CaloriesCard> createState() => _CaloriesCardState();
}

class _CaloriesCardState extends State<_CaloriesCard> {
  late final TextEditingController _limit = TextEditingController(
    text: _currentText,
  );
  String? _problem;

  String get _currentText {
    final target = widget.log.energyTargetOn(widget.date);
    return target == null ? '' : '${target.round()}';
  }

  @override
  void didUpdateWidget(_CaloriesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.energyTargetOn(widget.date) !=
        widget.log.energyTargetOn(widget.date)) {
      _limit.text = _currentText;
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    final limit = remove ? null : _positive(_limit);
    if (!remove && (limit == null || limit > 10000)) {
      setState(() => _problem = 'Enter a limit in kcal.');
      return;
    }
    setState(() => _problem = null);
    HapticFeedback.selectionClick();
    await saveOrShowError(
      context,
      () =>
          BodyActions(widget.appState)
              .setEnergyTarget(date: widget.date, energyKcal: limit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final textTheme = Theme.of(context).textTheme;
    final birthYear = log.birthYear;
    final bmr = basalMetabolicRate(
      sex: log.sex,
      weightKg: log.weightAsOf(widget.date),
      heightCm: log.heightCm,
      ageYears: birthYear == null ? null : DateTime.now().year - birthYear,
    );
    final hasLimit = _currentText.isNotEmpty;
    final isSaved = _limit.text.trim() == _currentText;
    return SectionCard(
      children: [
        CardHeader(
          icon: Icons.local_fire_department,
          title: 'Daily calories',
          action: _SourcesButton(),
        ),
        if (bmr == null)
          const NoteText(
            'Fill in about you and your weight above to work out your '
            'BMR: the energy your body uses at rest.',
          )
        else ...[
          InfoRow(
            values: [
              InfoValue(label: 'BMR (at rest)', value: '${bmr.round()} kcal'),
            ],
          ),
          const SizedBox(height: Spacing.small),
          const FieldLabel('Energy used in a day, by activity'),
          for (final level in ActivityLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.tight),
              child: Row(
                children: [
                  Expanded(
                    child: Text(level.description, style: textTheme.bodyMedium),
                  ),
                  Text(
                    '${(bmr * level.factor).round()} kcal',
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          const NoteText(
            'To lose weight slowly, eat about 300 to 500 kcal less than '
            'you use.',
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Daily limit',
                  suffixText: 'kcal',
                  errorText: _problem,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: Spacing.small),
            FilledButton.tonal(
              onPressed: isSaved ? null : _save,
              child: Text(isSaved && hasLimit ? 'Saved' : 'Save'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.small),
        const NoteText(
          'A new limit counts from today; past days keep theirs. It also '
          'sets the daily amounts of fat, carbs and sugars.',
        ),
        if (hasLimit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _save(remove: true),
              child: const Text('Remove the limit'),
            ),
          ),
      ],
    );
  }
}

/// The Settings card that opens the body screen.
class BodySettingsCard extends StatelessWidget {
  /// Creates the card.
  const BodySettingsCard({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        const CardHeader(
          icon: Icons.person_outline,
          title: 'Body and calories',
        ),
        const NoteText(
          'Sex, year of birth, height and weight work out your BMR; set a '
          'daily calorie limit from it.',
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => BodyScreen(appState: appState),
            ),
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Open'),
        ),
      ],
    );
  }
}
