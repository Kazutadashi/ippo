// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [AboutScreen] and `build_info.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/about_screen.dart';
import 'package:ippo/core/build_info.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)![1];
    expect(appVersion, version);
  });

  testWidgets('shows the name, the version, and unknown build facts', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    expect(find.text('一歩'), findsOneWidget);
    expect(find.text('千里の道も一歩から'), findsOneWidget);
    expect(find.text(appVersion), findsOneWidget);
    // Tests are not built with tool/build.sh, so the commit is unknown.
    expect(find.text('Unknown (not built with tool/build.sh)'), findsWidgets);
  });
}
