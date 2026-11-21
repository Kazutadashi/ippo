// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/charts/chart_card.dart';
import 'package:ippo/core/charts/chart_screen.dart';
import 'package:ippo/core/charts/charts_screen.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/modules/all_modules.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppState appState;

  setUp(() async {
    final settings = Directory.systemTemp.createTempSync('ippo_charts_');
    addTearDown(() => settings.deleteSync(recursive: true));
    appState = AppState(
      settingsFile: SettingsFile(settings.path),
      isAndroid: false,
      defaultDeviceName: 'my-phone',
    );
  });

  test('every module offers its charts from the demo data', () async {
    await appState.load();
    await startDemo(appState);
    final titles = [
      for (final module in allModules)
        for (final chart in module.charts(appState)) chart.title,
    ];
    expect(
      titles,
      containsAll([
        'Habits done',
        'Weight',
        'Energy',
        'Protein',
        'Steps',
        'Sleep',
        'Sleep times',
      ]),
    );
    for (final module in allModules) {
      for (final chart in module.charts(appState)) {
        expect(chart.values, isNotEmpty, reason: chart.title);
      }
    }
  });

  test('sleep times run from bedtime to waking up, around midnight', () async {
    await appState.load();
    await startDemo(appState);
    final sleepTimes = allModules
        .expand((module) => module.charts(appState))
        .firstWhere((chart) => chart.title == 'Sleep times');
    for (final night in sleepTimes.ranges) {
      expect(night.low, lessThan(night.high));
      expect(night.low, inInclusiveRange(-6, 6));
      expect(night.high, inInclusiveRange(0, 14));
    }
  });

  testWidgets('lists the charts by module; a row opens its chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await appState.load();
      await startDemo(appState);
    });
    await tester.pumpWidget(
      MaterialApp(home: ChartsScreen(appState: appState)),
    );
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
    expect(find.textContaining('per week'), findsWidgets);

    await tester.tap(find.text('Weight (kg)'));
    await tester.pumpAndSettle();
    expect(find.byType(ChartScreen), findsOneWidget);
    expect(find.byType(ChartCard), findsOneWidget);

    for (final period in ['Week', 'Month', 'Year', 'All', '3 mo']) {
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: period);
    }

    // On today, › is off; ‹ steps back by the same number of days.
    final later = find.ancestor(
      of: find.byTooltip('Later'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(later).onPressed, isNull);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    final weekShown = find.textContaining(' – ');
    final before = tester.widget<Text>(weekShown).data;
    await tester.tap(find.byTooltip('Earlier'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(weekShown).data, isNot(before));
    expect(tester.widget<IconButton>(later).onPressed, isNotNull);

    // Tapping near the right edge of the plot reads out a day.
    final plot = find.descendant(
      of: find.byType(ChartCard),
      matching: find.byType(CustomPaint),
    );
    final box = tester.getRect(plot.at(1));
    await tester.tapAt(Offset(box.right - 8, box.center.dy));
    await tester.pump();
    expect(find.text('7-day mean'), findsWidgets);
  });

  test('describeDays writes a span of days briefly', () {
    expect(
      describeDays(DateTime(2026, 10, 26), DateTime(2026, 11, 21)),
      '26 Oct – 21 Nov 2026',
    );
    expect(
      describeDays(DateTime(2025, 12, 1), DateTime(2026, 1, 31)),
      '1 Dec 2025 – 31 Jan 2026',
    );
  });

  testWidgets('says so when nothing is logged', (tester) async {
    await tester.runAsync(appState.load);
    await tester.pumpWidget(
      MaterialApp(home: ChartsScreen(appState: appState)),
    );
    expect(
      find.text('Charts show here once something is logged.'),
      findsOneWidget,
    );
  });
}
