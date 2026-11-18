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

  /// Tiles for the home screen with the most important things to know
  /// about today in this module, such as "Sleep: 7 h 30 min". Usually two,
  /// so they fill one row.
  ///
  /// A module returns the same tiles whether or not anything was logged,
  /// with "–" as the value until something is, so the home screen keeps
  /// its layout. [now] is the current time; tests pass a fixed one.
  List<TodayFact> todayFacts(AppState appState, DateTime now);
}

/// One tile on the home screen: an icon and label, a large value, and a
/// short detail, such as "Last meal", "3 h ago", "at 12:15 · Soup".
class TodayFact {
  /// Creates a tile's content.
  const TodayFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  /// The text shown for a value that is not known yet.
  static const String unknownValue = '–';

  /// The icon next to the label.
  final IconData icon;

  /// What the value is, for example `Last meal`.
  final String label;

  /// The value, shown large, for example `3 h ago`, or [unknownValue].
  final String value;

  /// One short line with more detail, for example `at 12:15 · Soup`.
  final String detail;
}
