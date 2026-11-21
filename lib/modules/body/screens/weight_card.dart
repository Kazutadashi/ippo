// SPDX-License-Identifier: GPL-3.0-or-later

/// The weight card: the day's weight, typed in once a day.
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

/// The weight on [date], with Save (Saved once it is), and below it the
/// last few weighings (or, when [isCompact], only the one before, while
/// the day has none). On the Body screen, and in compact form on the
/// Food tab, where it is easy to remember every day.
class WeightCard extends StatefulWidget {
  /// Creates the card for [date] (`YYYY-MM-DD`).
  const WeightCard({
    super.key,
    required this.appState,
    required this.log,
    required this.date,
    this.isCompact = false,
  });

  /// The app-wide state, for saving.
  final AppState appState;

  /// The body details, with every weighing.
  final BodyLog log;

  /// The day whose weight is typed in.
  final String date;

  /// Just the field and the last weighing, without the list of recent
  /// ones: for the Food tab, where it is a quick daily entry.
  final bool isCompact;

  @override
  State<WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<WeightCard> {
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
  void didUpdateWidget(WeightCard oldWidget) {
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
    final shown = parsePositive(_weight.text);
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
    final isToday = widget.date == formatDate(today());
    // The last weighing before this day, as a reminder of where things
    // were, when nothing is saved for this day yet.
    final earlier = [
      for (final weight in widget.log.weights.reversed)
        if (!weight.isDeleted && weight.date.compareTo(widget.date) < 0) weight,
    ].firstOrNull;
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
                  labelText: isToday ? 'Today' : describeDayOf(widget.date),
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
        if (widget.isCompact && _todaysText.isEmpty && earlier != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: NoteText(
              'Last weighed ${describeDayOf(earlier.date)}: '
              '${formatWeight(earlier.weightKg)}',
            ),
          ),
        if (!widget.isCompact)
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
