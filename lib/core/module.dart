// SPDX-License-Identifier: GPL-3.0-or-later

/// What every module (habits, exercise, food, ...) offers the core app.
///
/// The core knows nothing about any specific module. It only shows the
/// modules listed in `lib/modules/all_modules.dart`, using this
/// interface.
library;

import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'widgets/info_tile.dart';

export 'widgets/info_tile.dart' show TileDetail;

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
  /// about [day] in this module, such as "Sleep: 7 h 30 min": two half
  /// tiles, which fill one row, or one wide tile ([TodayFact.isWide]).
  ///
  /// [day] is today (see `currentDay` in `dates.dart`) unless the user
  /// looks back at another day on Home; then values worked out from the
  /// time ("3 h ago") become clock times. [now] is the current time;
  /// tests pass a fixed one.
  ///
  /// A module returns the same tiles whether or not anything was logged,
  /// with "–" as the value until something is, so the home screen keeps
  /// its layout.
  List<TodayFact> dayFacts(AppState appState, DateTime day, DateTime now);

  /// One number about the seven days ending on [day], for Home's "Last
  /// 7 days" tile, such as "Sleep / night" and "7 h 40 min". Null if the
  /// module has nothing to add, or nothing was logged.
  TileDetail? weekSummary(AppState appState, DateTime day) => null;
}

/// One tile on the home screen: a label, a large value, and small
/// facts below it. The tile's icon is its module's [IppoModule.icon].
///
/// For example: "Last meal", "3 h ago", then the lines "Soup" and
/// "at 12:15". Facts are never joined into one string; see [InfoTile]
/// for how they are laid out.
class TodayFact {
  /// Creates a tile's content.
  const TodayFact({
    required this.label,
    required this.value,
    this.details = const [],
    this.note,
    this.isWide = false,
  });

  /// The text shown for a value that is not known yet.
  static const String unknownValue = unknownTileValue;

  /// What the value is, for example `Last meal`.
  final String label;

  /// The value, shown large, for example `3 h ago`, or [unknownValue].
  final String value;

  /// Up to three small facts, for example a food's name and its time.
  final List<TileDetail> details;

  /// A short note instead of details, for example `Not logged yet`.
  final String? note;

  /// Whether the tile takes a whole row, for details that need the
  /// room, such as one column per exercise.
  final bool isWide;
}
