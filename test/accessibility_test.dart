// SPDX-License-Identifier: GPL-3.0-or-later

// Checks the main screens against Flutter's accessibility guidelines, in
// light and dark mode, with the demo data loaded:
//
// * tap targets at least 48 × 48 (Android's guidance);
// * every tap target labelled for screen readers;
// * text contrast at least 4.5:1 (3:1 for large text), as WCAG 2.2 AA asks;
// * no layout cut off with text 1.5 and 2 times as large.
//
// See "Accessibility" in docs/design.md, which also explains the one
// exception: the day grids on Home and Habits.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/about_screen.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/charts/chart_screen.dart';
import 'package:ippo/core/charts/charts_screen.dart';
import 'package:ippo/core/settings/settings_screen.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/core/theme.dart';
import 'package:ippo/core/today_screen.dart';
import 'package:ippo/modules/all_modules.dart';
import 'package:ippo/modules/body/screens/body_screen.dart';
import 'package:ippo/modules/exercise/screens/exercise_form_screen.dart';
import 'package:ippo/modules/exercise/screens/exercise_home_screen.dart';
import 'package:ippo/modules/food/screens/food_diary_screen.dart';
import 'package:ippo/modules/food/screens/foods_screen.dart';
import 'package:ippo/modules/habits/screens/habit_form_screen.dart';
import 'package:ippo/modules/habits/screens/habits_screen.dart';
import 'package:ippo/modules/sleep/screens/sleep_screen.dart';
import 'package:material_ui/material_ui.dart';

/// The smallest target WCAG 2.2 AA allows (success criterion 2.5.8).
/// Used for the day grids only, whose cells are a seventh of the screen
/// wide; everything else must meet Android's 48.
const MinimumTapTargetGuideline wcagTapTargetGuideline =
    MinimumTapTargetGuideline(
      size: Size(24, 24),
      link: 'https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum',
    );

/// Screens whose day grid is checked against [wcagTapTargetGuideline].
const Set<String> screensWithDayGrids = {'home', 'habits'};

void main() {
  late AppState appState;

  /// The screens checked, by name.
  final screens = <String, Widget Function()>{
    'home': () => TodayScreen(
      appState: appState,
      onOpenSettings: () {},
      onOpenCharts: () {},
      onOpenModule: (_) {},
    ),
    'habits': () => HabitsScreen(appState: appState),
    'food': () => FoodDiaryScreen(appState: appState),
    'exercise': () => ExerciseHomeScreen(appState: appState),
    'sleep': () => SleepScreen(appState: appState),
    'settings': () => SettingsScreen(appState: appState),
    'charts': () => ChartsScreen(appState: appState),
    'weight chart': () => ChartScreen(
      appState: appState,
      module: allModules.firstWhere((module) => module.moduleName == 'food'),
      title: 'Weight',
    ),
    'body': () => BodyScreen(appState: appState),
    'foods': () => FoodsScreen(appState: appState),
    'habit form': () => HabitFormScreen(appState: appState),
    'exercise form': () => ExerciseFormScreen(appState: appState),
    'about': () => const AboutScreen(),
  };

  /// Starts the demo in a fresh app state and shows [screen] on a phone-
  /// sized window, in [brightness], with text scaled by [textScale].
  Future<void> showScreen(
    WidgetTester tester,
    Widget Function() screen, {
    Brightness brightness = Brightness.dark,
    double textScale = 1,
  }) async {
    final settings = Directory.systemTemp.createTempSync('ippo_a11y_');
    addTearDown(() => settings.deleteSync(recursive: true));
    appState = AppState(
      settingsFile: SettingsFile(settings.path),
      isAndroid: false,
      defaultDeviceName: 'my-phone',
    );
    await tester.runAsync(() async {
      await appState.load();
      await startDemo(appState);
    });
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: buildTheme(const Color(0xFF1E88E5), brightness),
          home: screen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  for (final brightness in [Brightness.dark, Brightness.light]) {
    for (final entry in screens.entries) {
      final name = '${brightness.name} ${entry.key}';
      final tapTargets = screensWithDayGrids.contains(entry.key)
          ? wcagTapTargetGuideline
          : androidTapTargetGuideline;

      testWidgets('$name: tap targets are big enough', (tester) async {
        final semantics = tester.ensureSemantics();
        await showScreen(tester, entry.value, brightness: brightness);
        await expectLater(tester, meetsGuideline(tapTargets));
        semantics.dispose();
      });

      testWidgets('$name: tap targets are labelled', (tester) async {
        final semantics = tester.ensureSemantics();
        await showScreen(tester, entry.value, brightness: brightness);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });

      testWidgets('$name: text has enough contrast', (tester) async {
        final semantics = tester.ensureSemantics();
        await showScreen(tester, entry.value, brightness: brightness);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  }

  for (final scale in [1.5, 2.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits with text x$scale', (tester) async {
        await showScreen(tester, entry.value, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
