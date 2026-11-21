// SPDX-License-Identifier: GPL-3.0-or-later

/// Guards the promise that Ippo never uses the network, and that its
/// private files never leave the phone.
///
/// The Android release build must not request the INTERNET permission,
/// so the operating system itself blocks all network access. This test
/// fails if anyone adds that permission to the main manifest, or turns
/// Android's cloud backup or device transfer of the app's files back on.
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

  test('the app\'s private files never go into backups or transfers', () {
    final manifestText = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifestText, contains('android:allowBackup="false"'));
    expect(manifestText, contains('android:fullBackupContent="false"'));
    expect(
      manifestText,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(manifestText, contains('android:usesCleartextTraffic="false"'));

    // Android 12 and later: everything excluded from both.
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = rules.substring(
        rules.indexOf('<$section>'),
        rules.indexOf('</$section>'),
      );
      for (final domain in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(body, contains('<exclude domain="$domain" path="." />'));
      }
    }
  });
}
