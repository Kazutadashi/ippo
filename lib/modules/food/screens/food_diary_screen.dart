// SPDX-License-Identifier: GPL-3.0-or-later

/// The food module's main screen: what was eaten on one day.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/number_input.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../food_diary.dart';
import '../food_entry.dart';
import 'choose_food_screen.dart';
import 'food_entry_form_screen.dart';
import 'nutrient_summary.dart';
import 'quick_entry_form_screen.dart';

/// Shows one day's total, then everything eaten that day in the order
/// it was logged.
class FoodDiaryScreen extends StatefulWidget {
  /// Creates the diary screen.
  const FoodDiaryScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> {
  /// The day being shown, at local midnight. Starts at today.
  DateTime _day = today();

  void _addEntry() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChooseFoodScreen(
          appState: widget.appState,
          date: formatDate(_day),
          isToday: _day == today(),
        ),
      ),
    );
  }

  void _editEntry(FoodEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => entry.isQuickEntry
            ? QuickEntryFormScreen.edit(appState: widget.appState, entry: entry)
            : FoodEntryFormScreen.edit(appState: widget.appState, entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final events = widget.appState.eventLog?.events ?? [];
          final diary = FoodDiary.fromEvents(events);
          final date = formatDate(_day);
          final entries = diary.entriesOn(date);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DayBar(day: _day, onChanged: (day) => setState(() => _day = day)),
              if (diary.invalidCount > 0)
                ProblemText(
                  '${diary.invalidCount} foods or entries in the data '
                  'could not be read and are not shown.',
                ),
              SectionCard(
                children: [
                  const CardHeader(icon: Icons.functions, title: 'Total'),
                  const SizedBox(height: 8),
                  NutrientInfoRow(nutrients: diary.totalOn(date)),
                ],
              ),
              SectionCard(
                children: [
                  CardHeader(
                    icon: Icons.restaurant,
                    title: 'Eaten',
                    action: HeaderAddButton(onPressed: _addEntry),
                  ),
                  if (entries.isEmpty)
                    const NoteText('Nothing logged on this day.'),
                  for (final entry in entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.name),
                      subtitle: Text(_describeEntry(entry)),
                      trailing: IconButton(
                        tooltip: 'Edit entry',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editEntry(entry),
                      ),
                      onTap: () => _editEntry(entry),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Describes an entry, for example `07:30 · 150 g · 280 kcal` or
/// `Quick entry · 850 kcal`. The time is left out when it is not known.
String _describeEntry(FoodEntry entry) {
  final amount = entry.amount;
  final parts = [
    if (entry.time != null) entry.time!,
    if (amount == null) 'Quick entry',
    if (amount != null) '${formatAmount(amount)} ${entry.measuredIn ?? ''}',
    '${formatAmount(entry.nutrients.energyKcal)} kcal',
  ];
  return parts.join(' · ');
}
