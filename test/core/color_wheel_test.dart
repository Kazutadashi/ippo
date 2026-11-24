// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the color wheel and [CustomColorCircle].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/theme.dart';
import 'package:ippo/core/widgets/color_wheel.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tapping the wheel picks a color, Choose returns it', (
    tester,
  ) async {
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomColorCircle(
            color: null,
            purpose: 'accent color',
            onPicked: (color) => picked = color,
            asShown: (color) => color,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CustomColorCircle));
    await tester.pumpAndSettle();
    expect(find.text('Pick a color'), findsOneWidget);

    // The right edge of the wheel is pure red at full strength.
    // The wheel is the 220 by 220 square.
    final wheel = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.width == 220,
    );
    final box = tester.getRect(wheel);
    await tester.tapAt(Offset(box.right - 1, box.center.dy));
    await tester.pump();
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    final hsv = HSVColor.fromColor(picked!);
    expect(hsv.hue, closeTo(0, 1));
    expect(hsv.saturation, closeTo(1, 0.02));
  });

  testWidgets('a custom color shows on the circle with a tick', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomColorCircle(
            color: const Color(0xFF123456),
            purpose: 'habit color',
            onPicked: (_) {},
            asShown: (color) => color,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(isPresetColor(const Color(0xFF123456)), isFalse);
    expect(isPresetColor(accentChoices.first.color), isTrue);
  });

  test('swatches show the accent as the app does: softer on dark', () {
    const blue = Color(0xFF1E88E5);
    final onDark = accentAsShown(blue, Brightness.dark);
    final onLight = accentAsShown(blue, Brightness.light);
    // The app's dark-mode accent is lighter than the raw color, so the
    // swatch is too; and it is the theme's own main color.
    expect(onDark.computeLuminance(), greaterThan(blue.computeLuminance()));
    expect(onDark, buildTheme(blue, Brightness.dark).colorScheme.primary);
    expect(onLight, buildTheme(blue, Brightness.light).colorScheme.primary);
  });
}
