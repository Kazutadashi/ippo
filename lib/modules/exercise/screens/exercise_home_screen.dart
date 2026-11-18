// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module's main screen: progressions and exercises for one
/// day.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/widgets/day_bar.dart';
import '../exercise.dart';
import '../exercise_actions.dart';
import '../exercise_log.dart';
import '../exercise_set.dart';
import '../progression.dart';
import 'exercise_cards.dart';
import 'exercise_form_screen.dart';
import 'history_screen.dart';
import 'log_set_screen.dart';
import 'progression_form_screen.dart';

/// Shows every progression and standalone exercise with the day's sets.
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

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  void _logSet(
    ExerciseLog log,
    Exercise exercise, {
    Progression? progression,
    int? stepNumber,
  }) {
    _open(
      LogSetScreen.add(
        appState: widget.appState,
        exercise: exercise,
        date: formatDate(_day),
        progression: progression,
        stepNumber: stepNumber,
        // Start from the last set of this exercise: usually close.
        startValue: log.lastSetOf(exercise.id)?.value,
      ),
    );
  }

  /// Adds [setCount] sets of [value] reps (or seconds) of [exercise] on
  /// the day shown. Used by the quick-add row on each card.
  Future<void> _addSets(
    Exercise exercise,
    int value,
    int setCount, {
    Progression? progression,
    int? stepNumber,
  }) async {
    final actions = ExerciseActions(widget.appState);
    final date = formatDate(_day);
    await saveOrShowError(context, () async {
      for (var count = 0; count < setCount; count++) {
        // Count again each time, so each set gets the next number.
        final log = ExerciseLog.fromEvents(
          widget.appState.eventLog?.events ?? [],
        );
        await actions.recordSet(
          date: date,
          exercise: exercise,
          setNumber: log.setsOn(date, exercise.id).length + 1,
          value: value,
          weightKg: null,
          repsInReserve: null,
          progression: progression,
          stepNumber: stepNumber,
        );
      }
    });
  }

  void _editSet(ExerciseLog log, ExerciseSet set) {
    final exercise = log.exercises[set.exerciseId];
    if (exercise == null) {
      return;
    }
    _open(
      LogSetScreen.edit(
        appState: widget.appState,
        exercise: exercise,
        existingSet: set,
      ),
    );
  }

  Future<void> _moveToStep(Progression progression, int stepNumber) async {
    final actions = ExerciseActions(widget.appState);
    await saveOrShowError(
      context,
      () => actions.setProgressionStep(
        progression.id,
        stepNumber: stepNumber,
        date: formatDate(_day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (_) =>
                _open(ProgressionFormScreen(appState: widget.appState)),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'progression',
                child: Text('New progression (a ladder of exercises)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(ExerciseFormScreen(appState: widget.appState)),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final log = ExerciseLog.fromEvents(
            widget.appState.eventLog?.events ?? [],
          );
          return ListView(
            // Leave room at the bottom so the button never hides a card.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              DayBar(day: _day, onChanged: (day) => setState(() => _day = day)),
              if (log.invalidCount > 0)
                Text(
                  '${log.invalidCount} items in the data could not be read '
                  'and are not shown.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (log.activeProgressions.isEmpty &&
                  log.standaloneExercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Tap "New exercise" to start. Each exercise gets a card '
                    'where you add sets and reps for the day.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final exercise in log.standaloneExercises)
                ExerciseCard(
                  // A key per exercise keeps each card's typed numbers
                  // with the right card when the list changes.
                  key: ValueKey(exercise.id),
                  exercise: exercise,
                  daySets: log.setsOn(formatDate(_day), exercise.id),
                  startValue: log.lastSetOf(exercise.id)?.value,
                  onAddSets: (value, setCount) =>
                      _addSets(exercise, value, setCount),
                  onMoreOptions: () => _logSet(log, exercise),
                  onEditSet: (set) => _editSet(log, set),
                  onEdit: () => _open(
                    ExerciseFormScreen(
                      appState: widget.appState,
                      exercise: exercise,
                    ),
                  ),
                  onHistory: () => _open(
                    HistoryScreen.exercise(
                      appState: widget.appState,
                      exerciseId: exercise.id,
                    ),
                  ),
                ),
              for (final progression in log.activeProgressions)
                _buildProgressionCard(log, progression),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressionCard(ExerciseLog log, Progression progression) {
    final stepNumber = log.currentStepNumber(progression);
    final step = progression.stepAt(stepNumber);
    final exercise = log.exercises[step.exerciseId];
    return ProgressionCard(
      key: ValueKey(progression.id),
      progression: progression,
      stepNumber: stepNumber,
      exercise: exercise,
      daySets: log.setsOn(formatDate(_day), step.exerciseId),
      startValue: log.lastSetOf(step.exerciseId)?.value,
      onAddSets: (value, setCount) => _addSets(
        exercise!,
        value,
        setCount,
        progression: progression,
        stepNumber: stepNumber,
      ),
      onMoreOptions: () => _logSet(
        log,
        exercise!,
        progression: progression,
        stepNumber: stepNumber,
      ),
      onEditSet: (set) => _editSet(log, set),
      onMoveToStep: (number) => _moveToStep(progression, number),
      onEdit: () => _open(
        ProgressionFormScreen(
          appState: widget.appState,
          progression: progression,
        ),
      ),
      onHistory: () => _open(
        HistoryScreen.progression(
          appState: widget.appState,
          progressionId: progression.id,
        ),
      ),
    );
  }
}
