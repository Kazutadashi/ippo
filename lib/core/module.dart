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

export 'widgets/info_tile.dart' show LabelledValues, TileDetail;

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

  /// The module's row in Home's week grid: one mark for each of the
  /// seven days ending on [day], oldest first. Null for no row.
  WeekRow? weekRow(AppState appState, DateTime day) => null;
}

/// A module's tile on Home. Every tile has the same parts in the same
/// places, so tiles side by side line up: the module's icon and title
/// (from the module), then [value], then [mark], then [lines].
///
/// For example, Food: "1007 kcal" "so far", Protein / Carbs / Fat as the
/// mark, then "Last meal 8 h ago" and "7-day avg 1326 kcal".
class HomeTile {
  /// Creates a tile's content.
  const HomeTile({
    required this.value,
    this.valueNote,
    this.mark,
    this.lines = const [],
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

  /// Up to two short grey lines under the mark: one fact, such as
  /// `Last meal 8 h ago`, and then the comparison with the usual, always
  /// written out, such as `7-day avg 1326 kcal`. Or a note such as
  /// `Not logged yet`.
  final List<String> lines;
}

/// How a module's marks in the week grid are drawn.
enum WeekMarkShape {
  /// A circle, as full as the value: empty for 0, solid for 1. For yes
  /// and no (trained or not), or a share (habits done).
  dot,

  /// A small upright bar, as tall as the value: for an amount, such as
  /// hours slept.
  bar,
}

/// A module's row in Home's week grid.
class WeekRow {
  /// Creates the row.
  const WeekRow({
    required this.values,
    this.shape = WeekMarkShape.dot,
    required this.description,
  });

  /// Seven values from 0 to 1, oldest day first, the day shown last; null
  /// for a day without data.
  final List<double?> values;

  /// How the values are drawn.
  final WeekMarkShape shape;

  /// What a screen reader says for the row, such as "Habits done each
  /// day: 77 % on average".
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
