// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [DiscardGuard].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/widgets/discard_guard.dart';
import 'package:material_ui/material_ui.dart';

/// A tiny form: one field inside the guard, opened from a first screen.
class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DiscardGuard(
      snapshot: () => _field.text,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close without saving',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: TextField(controller: _field),
      ),
    );
  }
}

void main() {
  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const _Form())),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a form without changes closes at once', (tester) async {
    await openForm(tester);
    await tester.tap(find.byTooltip('Close without saving'));
    await tester.pumpAndSettle();
    expect(find.byType(_Form), findsNothing);
  });

  testWidgets('a form with changes asks first', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextField), 'Oats');
    await tester.tap(find.byTooltip('Close without saving'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(_Form), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);

    await tester.tap(find.byTooltip('Close without saving'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(_Form), findsNothing);
  });
}
