// SPDX-License-Identifier: GPL-3.0-or-later

/// The exercise module's main screen: one card per exercise, where the
/// day's sets are added.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/day_bar.dart';
import '../../../core/widgets/follows_today.dart';
import '../../../core/widgets/section_card.dart';
import '../exercise.dart';
import '../exercise_actions.dart';
import '../exercise_log.dart';
import '../exercise_set.dart';
import 'edit_set_screen.dart';
import 'exercise_cards.dart';
import 'exercise_form_screen.dart';
import 'steps_card.dart';

/// Shows every exercise with the day's sets and a quick way to add more.
class ExerciseHomeScreen extends StatefulWidget {
  /// Creates the screen.
  const ExerciseHomeScreen({super.key, required this.appState});

  /// The app-wide state, with the event log.
  final AppState appState;

  @override
  State<ExerciseHomeScreen> createState() => _ExerciseHomeScreenState();
}

class _ExerciseHomeScreenState extends State<ExerciseHomeScreen>
    with FollowsToday {
  ExerciseLog _currentLog() => ExerciseLog.of(widget.appState);

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  /// Adds one set, then offers to undo it, in case the tap was a
  /// mistake.
  Future<void> _addSet(Exercise exercise, int value) async {
    final actions = ExerciseActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final date = formatDate(shownDay);
    String? setId;
    final saved = await saveOrShowError(context, () async {
      final event = await actions.recordSet(
        date: date,
        exercise: exercise,
        setNumber: _currentLog().setsOn(date, exercise.id).length + 1,
        value: value,
      );
      setId = event.id;
    });
    final addedId = setId;
    if (saved && addedId != null) {
      showUndoMessage(
        messenger,
        message: 'Set added to ${exercise.name}',
        onUndo: () => actions.deleteSet(addedId),
      );
    }
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
      appBar: AppBar(
        title: const Text('Exercise'),
        actions: [DayBar(day: shownDay, onChanged: showDay)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Every floating button needs its own tag: all tabs stay alive at
        // once, and Flutter cannot animate two buttons with one tag.
        heroTag: 'new-exercise',
        onPressed: () => _open(ExerciseFormScreen(appState: widget.appState)),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: widget.appState.reloadEvents,
        child: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final log = _currentLog();
            return ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),

              // Leave room at the bottom so the button never hides a card.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
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
                // The day's steps first: one number, typed in once a day.
                StepsCard(
                  appState: widget.appState,
                  date: formatDate(shownDay),
                  saved: log.stepsOn(formatDate(shownDay)),
                ),
                // Says once how to fix a mistake, which is otherwise
                // hidden.
                if (log.activeExercises.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Spacing.small),
                    child: NoteText('Tap a set to change or remove it.'),
                  ),
                for (final exercise in log.activeExercises)
                  _card(log, exercise),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The card of [exercise] for the day shown.
  Widget _card(ExerciseLog log, Exercise exercise) {
    final date = formatDate(shownDay);
    final previous = log.previousSessionOf(exercise.id, date);
    return ExerciseCard(
      // A key per exercise keeps each card's typed numbers with the
      // right card when the list changes.
      key: ValueKey(exercise.id),
      exercise: exercise,
      day: shownDay,
      daySets: log.setsOn(date, exercise.id),
      previousDate: previous == null ? null : parseDate(previous.date),
      previousSets: previous == null ? const [] : previous.sets,
      startValue: log.lastSetOf(exercise.id)?.value,
      onAddSet: (value) => _addSet(exercise, value),
      onEditSet: (set) => _editSet(exercise, set),
      onEdit: () => _open(
        ExerciseFormScreen(appState: widget.appState, exercise: exercise),
      ),
    );
  }
}
