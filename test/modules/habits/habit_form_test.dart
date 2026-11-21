// SPDX-License-Identifier: GPL-3.0-or-later

// The habit form's preview: its marks can be tapped through, like the
// grid's.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/core/theme.dart';
import 'package:ippo/modules/habits/habit_marks.dart';
import 'package:ippo/modules/habits/screens/habit_form_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tapping a preview day cycles ✓, ✗ and nothing', (tester) async {
    final settings = Directory.systemTemp.createTempSync('ippo_form_');
    addTearDown(() => settings.deleteSync(recursive: true));
    final appState = AppState(
      settingsFile: SettingsFile(settings.path),
      isAndroid: false,
      defaultDeviceName: 'my-phone',
    );
    await tester.runAsync(appState.load);
    tester.view.physicalSize = const Size(393 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(const Color(0xFF1E88E5), Brightness.dark),
        home: HabitFormScreen(appState: appState),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Today starts empty, the three days before done.
    final today = find.bySemanticsLabel('Preview, today: not recorded');
    expect(today, findsOneWidget);
    expect(find.byType(BoldCheck), findsNWidgets(3));

    await tester.tap(today);
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Preview, today: done'), findsOneWidget);
    expect(find.byType(BoldCheck), findsNWidgets(4));

    await tester.tap(find.bySemanticsLabel('Preview, today: done'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Preview, today: not done'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Preview, today: not done'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Preview, today: not recorded'), findsOne);

    // A past day too.
    await tester.tap(find.bySemanticsLabel('Preview, a past day: done').at(1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.bySemanticsLabel('Preview, a past day: not done'),
      findsOneWidget,
    );
  });

  testWidgets('a ✗ shows as covered only while the chain holds', (
    tester,
  ) async {
    final settings = Directory.systemTemp.createTempSync('ippo_form_');
    addTearDown(() => settings.deleteSync(recursive: true));
    final appState = AppState(
      settingsFile: SettingsFile(settings.path),
      isAndroid: false,
      defaultDeviceName: 'my-phone',
    );
    await tester.runAsync(appState.load);
    tester.view.physicalSize = const Size(393 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(const Color(0xFF1E88E5), Brightness.dark),
        home: HabitFormScreen(appState: appState),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final pastDone = find.bySemanticsLabel('Preview, a past day: done');
    final pastNotDone = find.bySemanticsLabel('Preview, a past day: not done');
    final pastCovered = find.bySemanticsLabel('Preview, a past day: covered');

    // Every day: the middle one of the three past ✓ becomes ✗.
    await tester.tap(pastDone.at(1));
    await tester.pump(const Duration(seconds: 1));
    expect(pastNotDone, findsOneWidget);

    // Every other day: ✓ ✗ ✓ keeps the chain, so it is covered.
    await tester.tap(find.text('Every other day'));
    await tester.pump(const Duration(seconds: 1));
    expect(pastCovered, findsOneWidget);
    expect(find.byType(CoveredMark), findsOneWidget);

    // Tapping the covered day turns it to ✓, and again back to the dot:
    // the dot cannot be taken away while the chain holds.
    await tester.tap(pastCovered);
    await tester.pump(const Duration(seconds: 1));
    expect(pastCovered, findsNothing);
    expect(pastDone, findsNWidgets(3));
    await tester.tap(pastDone.at(1));
    await tester.pump(const Duration(seconds: 1));
    expect(pastCovered, findsOneWidget);

    // The newer ✓ becomes ✗ too: the chain broke, so both are ✗.
    await tester.tap(pastDone.first);
    await tester.pump(const Duration(seconds: 1));
    expect(pastCovered, findsNothing);
    expect(pastNotDone, findsNWidgets(2));
  });
}
