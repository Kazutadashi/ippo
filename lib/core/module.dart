// SPDX-License-Identifier: GPL-3.0-or-later

/// What every module (habits, exercise, food, ...) offers the core app.
///
/// The core knows nothing about any specific module. It only shows the
/// modules listed in `lib/modules/all_modules.dart`, using this
/// interface.
library;

import 'package:material_ui/material_ui.dart';

import 'app_state.dart';

/// A module: one area of the app, such as the food diary.
abstract class IppoModule {
  /// The module's name in event files, for example `food`. It must never
  /// change, because it is stored in every event the module writes.
  String get moduleName;

  /// The module's name on screen, for example `Food`.
  String get title;

  /// The icon shown next to the module's title.
  IconData get icon;

  /// Builds the module's main screen.
  Widget buildScreen(AppState appState);

  /// The most important facts about today in this module, for the home
  /// screen: at most three, such as "Slept: 7 h 30 min". An empty list
  /// means nothing was logged today.
  ///
  /// [now] is the current time; tests pass a fixed one.
  List<TodayFact> todayFacts(AppState appState, DateTime now);
}

/// One fact for the home screen: a short label and its value, such as
/// "Last ate" and "3 h ago".
class TodayFact {
  /// Creates a fact.
  const TodayFact(this.label, this.value);

  /// What the value is, for example `Slept`.
  final String label;

  /// The value, for example `7 h 30 min`.
  final String value;
}
