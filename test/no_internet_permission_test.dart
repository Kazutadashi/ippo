// SPDX-License-Identifier: GPL-3.0-or-later

/// Guards the promise that Ippo never uses the network.
///
/// The Android release build must not request the INTERNET permission,
/// so the operating system itself blocks all network access. This test
/// fails if anyone adds that permission to the main manifest.
///
/// The debug and profile manifests are allowed to have it, because the
/// Flutter tool needs it for hot reload and debugging. Those manifests
/// are never used for release builds.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release Android manifest does not request INTERNET', () {
    // Tests run from the project root, so this relative path is stable.
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final manifestText = manifest.readAsStringSync();

    expect(manifestText, isNot(contains('android.permission.INTERNET')));
  });
}
