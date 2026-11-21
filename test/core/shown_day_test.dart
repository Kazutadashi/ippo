// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the day the screens show, shared by every tab.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/app_state.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/storage/settings_file.dart';

void main() {
  test('one day for every tab; picking today follows today again', () {
    final appState = AppState(
      settingsFile: SettingsFile('/path/to/settings'),
      isAndroid: false,
      defaultDeviceName: 'my-desktop',
    );
    var told = 0;
    appState.addListener(() => told++);

    expect(appState.shownDay, today());
    final yesterday = addDays(today(), -1);
    appState.showDay(yesterday);
    expect(appState.shownDay, yesterday);
    expect(told, 1);

    appState.showDay(today());
    expect(appState.shownDay, today());
    expect(told, 2);

    // There is no data ahead: a later day shows today instead.
    appState.showDay(addDays(today(), 1));
    expect(appState.shownDay, today());
  });
}
