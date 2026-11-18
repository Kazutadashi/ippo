// SPDX-License-Identifier: GPL-3.0-or-later

/// Changing or deleting a logged wake-up or bedtime.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/dates.dart';
import '../../../core/save_or_show_error.dart';
import '../../../core/undo_message.dart';
import '../../../core/widgets/section_card.dart';
import '../sleep_actions.dart';
import '../sleep_moment.dart';
import '../sleep_times.dart';
import 'sleep_widgets.dart';

/// The form for one wake-up or bedtime: its time, with the calendar day
/// shown below it.
class MomentFormScreen extends StatefulWidget {
  /// Creates the form for [moment].
  ///
  /// [wokeUp] is that day's wake-up time, if known; it decides whether a
  /// bedtime is after midnight.
  const MomentFormScreen({
    super.key,
    required this.appState,
    required this.moment,
    required this.wokeUp,
  });

  /// The app-wide state.
  final AppState appState;

  /// The wake-up or bedtime being changed.
  final SleepMoment moment;

  /// The day's wake-up time, if known.
  final ClockTime? wokeUp;

  @override
  State<MomentFormScreen> createState() => _MomentFormScreenState();
}

class _MomentFormScreenState extends State<MomentFormScreen> {
  late ClockTime _time = widget.moment.clock;

  DateTime get _day => parseDate(widget.moment.date)!;

  bool get _isBedtime => widget.moment.kind == MomentKind.wentToBed;

  DateTime _momentAt() {
    return _isBedtime
        ? bedtimeMoment(_day, _time, widget.wokeUp)
        : wakeUpMoment(_day, _time);
  }

  Future<void> _save() async {
    final actions = SleepActions(widget.appState);
    final saved = await saveOrShowError(
      context,
      () => actions.changeMoment(widget.moment, _momentAt()),
    );
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final moment = widget.moment;
    final actions = SleepActions(widget.appState);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await saveOrShowError(
      context,
      () => actions.deleteMoment(moment),
    );
    if (!deleted || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    showUndoMessage(
      messenger,
      message: '${moment.kind.label} time deleted.',
      onUndo: () => actions.restoreMoment(moment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.moment.kind.label;
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TimeField(
            label: label,
            time: _time,
            onChanged: (time) => setState(() => _time = time),
          ),
          const SizedBox(height: 8),
          NoteText(describeMomentDay(_momentAt(), _day)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
          DeleteButton(
            label: _isBedtime ? 'Delete this bedtime' : 'Delete this wake-up',
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}

/// Describes which calendar day a moment is on, for example `Wed 18 Nov`
/// or `Thu 19 Nov, after midnight` for a bedtime after midnight of
/// [day].
String describeMomentDay(DateTime moment, DateTime day) {
  final calendarDay = DateTime(moment.year, moment.month, moment.day);
  final text = formatShortDate(calendarDay);
  return calendarDay == day ? text : '$text, after midnight';
}
