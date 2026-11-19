// SPDX-License-Identifier: GPL-3.0-or-later

/// Keeping a screen on "today" as time passes.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../dates.dart';

/// For screens that show a day, or values that depend on the time.
///
/// Every tab stays alive, and Android keeps the app around for days.
/// Without this, a screen opened last night would still show last night
/// this morning, and new entries would quietly go to that day.
///
/// So the screen follows today unless the user picked another day with
/// the day bar ([showDay]). It is redrawn once a minute and whenever the
/// app comes back to the front, so it moves on to a new day by itself,
/// and times such as "25 min ago" stay current.
mixin FollowsToday<T extends StatefulWidget> on State<T> {
  /// The day picked with the day bar, or null to follow today.
  DateTime? _pickedDay;

  Timer? _minuteTimer;
  AppLifecycleListener? _lifecycle;

  /// The day the screen shows, at local midnight.
  DateTime get shownDay => _pickedDay ?? today();

  /// Whether the screen shows today.
  bool get showsToday => shownDay == today();

  /// Shows [day]. Picking today goes back to following today.
  void showDay(DateTime day) {
    setState(() => _pickedDay = day == today() ? null : day);
  }

  @override
  void initState() {
    super.initState();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) => _redraw());
    _lifecycle = AppLifecycleListener(onResume: _redraw);
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _redraw() {
    if (mounted) {
      setState(() {});
    }
  }
}
