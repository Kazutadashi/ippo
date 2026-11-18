// SPDX-License-Identifier: GPL-3.0-or-later

/// Checks that the app starts and shows its first screen.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/storage/settings_file.dart';
import 'package:ippo/main.dart';

void main() {
  late Directory temporaryFolder;

  setUp(() {
    temporaryFolder = Directory.systemTemp.createTempSync('ippo_test_');
  });

  tearDown(() {
    temporaryFolder.deleteSync(recursive: true);
  });

  testWidgets('on first run, the app asks for a data folder', (tester) async {
    final appState = AppState(
      settingsFile: SettingsFile(temporaryFolder.path),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );

    await tester.pumpWidget(IppoApp(appState: appState));
    // Real file access needs runAsync inside widget tests.
    await tester.runAsync(appState.load);
    await tester.pump();

    expect(find.text('Ippo'), findsOneWidget);
    expect(find.text('Choose a data folder'), findsOneWidget);
  });
}
