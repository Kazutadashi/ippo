// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the app starts on the right tab, that the home tab leads
/// to the modules, and that the chosen theme is applied.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/core/today_screen.dart';
import 'package:ippo/core/widgets/day_bar.dart';
import 'package:ippo/core/widgets/info_tile.dart';
import 'package:ippo/core/widgets/lately_card.dart';
import 'package:ippo/core/widgets/week_grid.dart';
import 'package:ippo/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory settingsFolder;
  late Directory dataFolder;

  setUp(() {
    settingsFolder = Directory.systemTemp.createTempSync('ippo_settings_');
    dataFolder = Directory.systemTemp.createTempSync('ippo_data_');
  });

  tearDown(() {
    settingsFolder.deleteSync(recursive: true);
    dataFolder.deleteSync(recursive: true);
  });

  AppState makeAppState() => AppState(
    settingsFile: SettingsFile(settingsFolder.path),
    isAndroid: false,
    defaultDeviceName: 'my-desktop',
  );

  /// Starts the app. Real file access needs runAsync in widget tests.
  Future<AppState> startApp(
    WidgetTester tester, {
    bool withDataFolder = true,
    Future<void> Function(AppState appState)? before,
  }) async {
    final appState = makeAppState();
    await tester.runAsync(() async {
      await appState.load();
      if (withDataFolder) {
        await appState.chooseLinuxDataFolder(dataFolder.path);
      }
      if (before != null) {
        await before(appState);
      }
    });
    await tester.pumpWidget(IppoApp(appState: appState));
    await tester.pump();
    return appState;
  }

  testWidgets('on a wide window, the tabs go down the side', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await startApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // Home shows more tiles per row: the first three share one row.
    final tiles = find.byType(HomeTileCard);
    final firstTop = tester.getTopLeft(tiles.at(0)).dy;
    expect(tester.getTopLeft(tiles.at(2)).dy, firstTop);
  });

  testWidgets('on first run, the app asks for a data folder', (tester) async {
    await startApp(tester, withDataFolder: false);

    expect(find.text('Choose a data folder'), findsOneWidget);
    // Five tabs: Home and the four modules. Settings is not a tab.
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);

    await tester.tap(find.text('Choose a data folder'));
    await tester.pumpAndSettle();
    expect(find.text('Data folder'), findsOneWidget);
  });

  testWidgets('tapping a Home tile opens its tab', (tester) async {
    await startApp(tester);

    await tester.tap(find.text('SLEEP'));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
  });

  testWidgets('the gear on Home opens Settings', (tester) async {
    await startApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Data folder'), findsOneWidget);
  });

  testWidgets('with a data folder, the app opens on Home', (tester) async {
    await startApp(tester);

    expect(find.text(greetingFor(DateTime.now())), findsOneWidget);
    expect(find.text(describeToday(today())), findsOneWidget);
    // A tile per module, all waiting for data, and no week yet: three
    // quiet dashes, and Exercise says its steps are not in yet.
    expect(find.byType(HomeTileCard), findsNWidgets(4));
    expect(find.text('–'), findsNWidgets(3));
    expect(find.text('No steps yet'), findsOneWidget);
    expect(find.byType(WeekGrid), findsNothing);
    // Everything tappable is the gear, the Charts button, the day bar,
    // or a tile (which opens its tab).
    bool isTappable(Widget widget) =>
        widget is ButtonStyleButton || widget is InkWell;
    final tappable = find.descendant(
      of: find.byType(TodayScreen),
      matching: find.byWidgetPredicate(isTappable),
    );
    final expected = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is IconButton || widget is DayBar || widget is HomeTileCard,
      ),
      matching: find.byWidgetPredicate(isTappable),
    );
    // The Charts button: the button itself and what it is made of.
    final charts = find.descendant(
      of: find.widgetWithText(TextButton, 'Charts'),
      matching: find.byWidgetPredicate(isTappable),
      matchRoot: true,
    );
    expect(
      tappable.evaluate().length,
      expected.evaluate().length + charts.evaluate().length,
    );
  });

  testWidgets('Home shows what was logged today', (tester) async {
    await startApp(
      tester,
      before: (appState) async {
        await appState.writeEvent(
          module: 'food',
          type: 'food_entry_recorded',
          data: {
            'date': formatDate(today()),
            'meal': 'snack',
            'name': 'Apple',
            'nutrients': {'energy_kcal': 80},
          },
        );
      },
    );

    // The Food tile shows today's total so far and the week grid a row
    // for food. Lately is not shown: it leaves out today, which is not
    // over, so with only today logged it has nothing to say yet.
    expect(find.text('FOOD'), findsOneWidget);
    expect(find.text('80 kcal'), findsOneWidget);
    expect(find.text('so far'), findsOneWidget);
    expect(find.byType(WeekGrid), findsOneWidget);
    expect(find.byType(LatelyCard), findsNothing);
  });

  testWidgets('tapping a day in the week grid shows that day', (tester) async {
    await startApp(
      tester,
      before: (appState) async {
        await appState.writeEvent(
          module: 'food',
          type: 'food_entry_recorded',
          data: {
            'date': formatDate(today()),
            'name': 'Apple',
            'nutrients': {'energy_kcal': 80},
          },
        );
      },
    );

    final yesterday = addDays(today(), -1);
    await tester.tap(
      find.bySemanticsLabel('Show ${formatShortDate(yesterday)}'),
    );
    await tester.pumpAndSettle();

    // The grid keeps its seven days: today is still its last column.
    expect(
      find.bySemanticsLabel('Show ${formatShortDate(today())}'),
      findsOneWidget,
    );
    // The day bar now shows yesterday.
    expect(
      find.descendant(
        of: find.byType(DayBar),
        matching: find.text('Yesterday'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Go to today'), findsOneWidget);
  });

  test('the greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Good evening');
    // Before 05:00 it is still the evening before (see dayStartHour).
    expect(greetingFor(DateTime(2026, 1, 2, 1, 30)), 'Good evening');
  });

  testWidgets('dark mode and the accent colour are applied', (tester) async {
    await startApp(
      tester,
      before: (appState) async {
        await appState.setThemeMode('dark');
        await appState.setAccentColor('#FB8C00');
      },
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    // The theme is built from the chosen colour.
    final darkPrimary = app.darkTheme!.colorScheme.primary;
    final defaultPrimary = makeTheme(const Color(0xFF00897B));
    expect(darkPrimary, isNot(defaultPrimary));
  });
}

/// The dark theme's main colour for [accent], for comparing.
Color makeTheme(Color accent) => ColorScheme.fromSeed(
  seedColor: accent,
  brightness: Brightness.dark,
  dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
).primary;
