// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the app starts and shows its first screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/main.dart';

void main() {
  testWidgets('the app starts and shows its name', (tester) async {
    await tester.pumpWidget(const IppoApp());

    expect(find.text('Ippo'), findsOneWidget);
  });
}
