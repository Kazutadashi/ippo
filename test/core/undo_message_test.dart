// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the undo message goes away by itself, or with its ✕.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/undo_message.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Builds an empty screen and shows an undo message on it.
  Future<List<String>> showMessage(WidgetTester tester) async {
    final undoCalls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUndoMessage(
                ScaffoldMessenger.of(context),
                message: 'Deleted Apple.',
                onUndo: () => undoCalls.add('undo'),
              ),
              child: const Text('Delete'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    return undoCalls;
  }

  testWidgets('hides itself after a few seconds', (tester) async {
    await showMessage(tester);
    expect(find.text('Deleted Apple.'), findsOneWidget);

    await tester.pump(undoMessageDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Deleted Apple.'), findsNothing);
  });

  testWidgets('the ✕ closes it without undoing', (tester) async {
    final undoCalls = await showMessage(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Deleted Apple.'), findsNothing);
    expect(undoCalls, isEmpty);
  });

  testWidgets('Undo calls back', (tester) async {
    final undoCalls = await showMessage(tester);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undoCalls, ['undo']);
  });
}
