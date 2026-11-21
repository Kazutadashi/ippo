// SPDX-License-Identifier: GPL-3.0-or-later

/// Keeping a screen on "today" as time passes, and on the same day as
/// every other tab.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../dates.dart';

/// For screens that show a day, or values that depend on the time.
///
/// Every tab stays alive, and Android keeps the app around for days.
/// Without this, a screen opened last night would still show last night
/// this morning, and new entries would quietly go to that day.
///
/// So the screen follows today unless the user picked another day with
/// the day bar ([showDay]). The picked day is kept in [AppState], shared
/// by every tab: moving to yesterday on Food shows yesterday on Sleep
/// too. The screen is redrawn once a minute, whenever the app comes back
/// to the front, and when the day changes, so it moves on to a new day
/// by itself, and times such as "25 min ago" stay current.
///
/// A screen using this says which [AppState] holds the day, with
/// [dayState].
mixin FollowsToday<T extends StatefulWidget> on State<T> {
  Timer? _minuteTimer;
  AppLifecycleListener? _lifecycle;

  // The day shown at the last redraw, so a change of the app state that
  // is not a change of day (a new entry, say) does not redraw here: the
  // screen's own builder redraws for those.
  DateTime? _lastShownDay;

  /// The app-wide state that holds the day shown (usually
  /// `widget.appState`).
  AppState get dayState;

  /// The day the screen shows, at local midnight.
  DateTime get shownDay => dayState.shownDay;

  /// Whether the screen shows today.
  bool get showsToday => shownDay == today();

  /// Shows [day] on every tab; today means "follow today" again.
  void showDay(DateTime day) => dayState.showDay(day);

  @override
  void initState() {
    super.initState();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) => _redraw());
    _lifecycle = AppLifecycleListener(onResume: _redraw);
    _lastShownDay = shownDay;
    dayState.addListener(_redrawIfDayChanged);
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _lifecycle?.dispose();
    dayState.removeListener(_redrawIfDayChanged);
    super.dispose();
  }

  void _redrawIfDayChanged() {
    if (shownDay != _lastShownDay) {
      _lastShownDay = shownDay;
      _redraw();
    }
  }

  void _redraw() {
    if (mounted) {
      setState(() {});
    }
  }
}
