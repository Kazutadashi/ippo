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
import 'weight_card.dart';

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
            padding: belowNavigationBar(
              context,
              const EdgeInsets.fromLTRB(16, 4, 16, 24),
            ),
            children: [
              _ProfileCard(appState: appState, log: log),
              WeightCard(appState: appState, log: log, date: date),
              _CaloriesCard(log: log, date: date),
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

  /// The height typed in feet and inches, in centimeters, or null.
  double? _imperialHeight() {
    final feet = int.tryParse(_feet.text.trim()) ?? 0;
    final inches =
        double.tryParse(_inches.text.trim().replaceAll(',', '.')) ?? 0;
    if (feet <= 0 && inches <= 0) {
      return null;
    }
    return centimetersFrom(feet, inches);
  }

  /// A number field with a [label] and a [unit] after the number.
  Widget _number(TextEditingController field, String label, String unit) {
    return TextField(
      controller: field,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, suffixText: unit),
      // Redraw, so the button turns from "Saved" back to "Save".
      onChanged: (_) => setState(() {}),
    );
  }

  /// Whether what is on screen is what was last saved, so the button
  /// can say "Saved", as the weight and limit buttons do.
  bool get _isSaved {
    final log = widget.log;
    final heightCm = log.heightCm;
    if (log.sex == null || log.birthYear == null || heightCm == null) {
      return false;
    }
    final height = showImperialUnits
        ? _imperialHeight()
        : parsePositive(_height.text);
    return _sex == log.sex &&
        int.tryParse(_birthYear.text.trim()) == log.birthYear &&
        height != null &&
        (height - heightCm).abs() < 0.05;
  }

  Future<void> _save() async {
    final sex = _sex;
    final year = int.tryParse(_birthYear.text.trim());
    final height = showImperialUnits
        ? _imperialHeight()
        : parsePositive(_height.text);
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
                onChanged: (_) => setState(() {}),
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
        FilledButton.tonal(
          onPressed: _isSaved ? null : _save,
          child: Text(_isSaved ? 'Saved' : 'Save'),
        ),
      ],
    );
  }
}

/// The BMR and the energy used in a day at each activity level: the
/// numbers that help choose a daily calorie limit. The limit itself is
/// set with the other daily goals, on the Food tab.
class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.log, required this.date});

  final BodyLog log;
  final String date;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final birthYear = log.birthYear;
    final bmr = basalMetabolicRate(
      sex: log.sex,
      weightKg: log.weightAsOf(date),
      heightCm: log.heightCm,
      ageYears: birthYear == null ? null : DateTime.now().year - birthYear,
    );
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
              InfoValue(
                label: 'Burned at rest (BMR)',
                value: '${formatThousands(bmr.round())} kcal',
              ),
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
                    '${formatThousands((bmr * level.factor).round())} kcal',
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
        const SizedBox(height: Spacing.small),
        const NoteText(
          'Set your daily calorie limit with your other daily goals: '
          'Food › Total › Daily goals.',
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
