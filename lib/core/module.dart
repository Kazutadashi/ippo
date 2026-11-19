// SPDX-License-Identifier: GPL-3.0-or-later

/// What every module (habits, exercise, food, ...) offers the core app.
///
/// The core knows nothing about any specific module. It only shows the
/// modules listed in `lib/modules/all_modules.dart`, using this
/// interface.
library;

import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'dates.dart';
import 'widgets/info_tile.dart';

export 'widgets/info_tile.dart' show LabelledValues, TileDetail, TileRow;

/// A module: one area of the app, such as the food diary.
abstract class IppoModule {
  /// Lets modules be constant, as in `allModules`.
  const IppoModule();

  /// The module's name in event files, for example `food`. It must never
  /// change, because it is stored in every event the module writes.
  String get moduleName;

  /// The module's name on screen, for example `Food`. Home uses it as
  /// the label of the module's tile and of its row in the week grid.
  String get title;

  /// The icon shown next to the module's title.
  IconData get icon;

  /// The module's icon as a widget, for the tab bar, its Home tile and
  /// its cards. It is [icon] unless a module draws its own; either way it
  /// takes its size and colour from the surrounding `IconTheme`.
  Widget buildIcon() => Icon(icon);

  /// Builds the module's main screen.
  Widget buildScreen(AppState appState);

  /// The module's tile on Home for [day]: today's value, one small mark,
  /// and a line or two of grey text, the 7-day average last. See
  /// [HomeTile].
  ///
  /// [day] is today (see `currentDay` in `dates.dart`) unless the user
  /// looks back at another day on Home; then values worked out from the
  /// time ("3 h ago") become clock times. [now] is the current time;
  /// tests pass a fixed one.
  ///
  /// The tile keeps its shape whether or not anything was logged, with
  /// "–" as the value until something is, so Home never jumps.
  HomeTile homeTile(AppState appState, DateTime day, DateTime now);

  /// The module's rows in Home's week grid, usually one: one value for
  /// each of the seven days ending on [day], oldest first. Empty for no
  /// row.
  List<WeekRow> weekRows(AppState appState, DateTime day) => const [];

  /// A card for the Settings screen, such as Food's body details and
  /// calorie limit, or null for none.
  Widget? buildSettingsCard(AppState appState) => null;

  /// Every day (`YYYY-MM-DD`) with anything logged in this module, for
  /// Home's logging calendar, which shows days with gaps in the data.
  Set<String> datesLogged(AppState appState) => const {};
}

/// A module's tile on Home. Every tile has the same parts in the same
/// places, so tiles side by side line up: the module's icon and title
/// (from the module), then [value], then [mark], then [rows].
///
/// For example, Food: "1007 kcal" "so far", Protein / Carbs / Fat as the
/// mark, then the rows "Left today 993 kcal" and "Daily avg (7 days)
/// 1326 kcal".
class HomeTile {
  /// Creates a tile's content.
  const HomeTile({
    required this.value,
    this.valueNote,
    this.mark,
    this.note,
    this.rows = const [],
  });

  /// The text shown for a value that is not known yet.
  static const String unknownValue = unknownTileValue;

  /// Today's value, shown large, for example `4 of 5` or `7 h 8 min`, or
  /// [unknownValue].
  final String value;

  /// A word or two after the value that says what it is, such as
  /// `so far` or `done`.
  final String? valueNote;

  /// One small picture under the value, such as one dot per habit or
  /// last night as a bar. Built by the module, so it can draw its data.
  final Widget? mark;

  /// A short note in the mark's place when there is nothing to draw,
  /// saying exactly what is missing, such as `Bedtime not logged`.
  final String? note;

  /// Up to two rows of a label and a number, the numbers lined up at the
  /// right edge: one fact about today, then the usual, such as "Daily
  /// avg (7 days)". Labels say plainly what the number is, so anyone can
  /// read the tile without asking.
  final List<TileRow> rows;
}

/// A module's row in Home's week grid: one short value per day.
class WeekRow {
  /// Creates the row.
  const WeekRow({
    required this.label,
    required this.cells,
    required this.description,
  });

  /// The row's name with its unit, such as `Sleep (h)` or `Food (kcal)`,
  /// so the numbers need no unit of their own.
  final String label;

  /// Seven short values, oldest day first, the day shown last, such as
  /// `7.5` or `1840`; null for a day without data.
  final List<String?> cells;

  /// What a screen reader says for the row, such as "Sleep each night,
  /// 7 h 40 min on average".
  final String description;
}

/// How many days before the day shown make up "the usual": the 7-day
/// averages on Home.
const int usualDays = 7;

/// The [usualDays] days before [day], most recent first. The day itself
/// is left out: it is usually not over yet, so it would pull an average
/// down.
List<DateTime> daysBefore(DateTime day) => [
  for (var back = 1; back <= usualDays; back++) addDays(day, -back),
];

/// The seven days ending on [day], oldest first: the columns of the week
/// grid.
List<DateTime> weekEndingOn(DateTime day) => [
  for (var back = 6; back >= 0; back--) addDays(day, -back),
];
