// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module's main screen: one card per exercise, where the
/// day's sets are added.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_actions.dart';
import '../exercise_log.dart';
import '../exercise_set.dart';
import 'edit_set_screen.dart';
import 'exercise_cards.dart';
import 'exercise_form_screen.dart';

/// Shows every exercise with the day's sets and a quick way to add more.
class ExerciseHomeScreen extends StatefulWidget {
  /// Creates the screen.
  const ExerciseHomeScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<ExerciseHomeScreen> createState() => _ExerciseHomeScreenState();
}

class _ExerciseHomeScreenState extends State<ExerciseHomeScreen> {
  /// The day being shown, at local midnight. Starts at today.
  DateTime _day = today();

  ExerciseLog _currentLog() =>
      ExerciseLog.fromEvents(widget.appState.eventLog?.events ?? []);

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  Future<void> _addSets(Exercise exercise, int value, int setCount) async {
    final actions = ExerciseActions(widget.appState);
    await saveOrShowError(
      context,
      () => actions.recordSets(
        date: formatDate(_day),
        exercise: exercise,
        value: value,
        setCount: setCount,
        log: _currentLog(),
      ),
    );
  }

  void _editSet(Exercise exercise, ExerciseSet set) {
    _open(
      EditSetScreen(
        appState: widget.appState,
        exercise: exercise,
        existingSet: set,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(ExerciseFormScreen(appState: widget.appState)),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final log = _currentLog();
          final date = formatDate(_day);
          return ListView(
            // Leave room at the bottom so the button never hides a card.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              DayBar(day: _day, onChanged: (day) => setState(() => _day = day)),
              if (log.invalidCount > 0)
                ProblemText(
                  '${log.invalidCount} items in the data could not be read '
                  'and are not shown.',
                ),
              if (log.activeExercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: NoteText(
                    'Tap "New exercise" to start. Each exercise gets a card '
                    'where you add the day\'s sets and reps.',
                  ),
                ),
              for (final exercise in log.activeExercises)
                ExerciseCard(
                  // A key per exercise keeps each card's typed numbers
                  // with the right card when the list changes.
                  key: ValueKey(exercise.id),
                  exercise: exercise,
                  daySets: log.setsOn(date, exercise.id),
                  startValue: log.lastSetOf(exercise.id)?.value,
                  onAddSets: (value, setCount) =>
                      _addSets(exercise, value, setCount),
                  onEditSet: (set) => _editSet(exercise, set),
                  onEdit: () => _open(
                    ExerciseFormScreen(
                      appState: widget.appState,
                      exercise: exercise,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
