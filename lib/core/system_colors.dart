// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading the phone's own accent colour.
library;

import 'dart:io';

import 'package:flutter/services.dart';

/// The channel to the Kotlin code that reads the colour. Its name must
/// match `SystemColors.CHANNEL_NAME` in
/// `android/app/src/main/kotlin/org/ippo/ippo/SystemColors.kt`.
const MethodChannel _systemColorsChannel = MethodChannel(
  'org.ippo.ippo/system_colors',
);

/// Returns the accent colour chosen in the phone's system settings (or
/// taken from its wallpaper), or null if there is none.
///
/// Only Android 12 and later have one. On Linux, on older Android, or if
/// Android does not answer, this returns null and the app uses the
/// colour picked in Ippo's own settings instead. A missing system colour
/// is not an error: it only changes how the app looks.
Future<Color?> readSystemAccentColor() async {
  if (!Platform.isAndroid) {
    return null;
  }
  try {
    final argb = await _systemColorsChannel.invokeMethod<int>('accentColor');
    return argb == null ? null : Color(argb);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
