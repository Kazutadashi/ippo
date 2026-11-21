// SPDX-License-Identifier: GPL-3.0-or-later

/// Reading the name of the device's time zone, such as `Europe/Paris`.
///
/// Each event records it (see "Event fields" in `docs/data-format.md`),
/// because a time zone offset alone cannot tell a daylight saving change
/// from a trip, and analyses of sleep or meal times need to know which.
///
/// It lives with the storage code because on Linux it reads where the
/// system's `/etc/localtime` link points: only the link's target, never a
/// file's contents, and nothing of the user's.
library;

import 'dart:io';

import 'package:flutter/services.dart';

/// The channel to the Kotlin code that reads the zone. Its name must
/// match `SystemTimeZone.CHANNEL_NAME` in
/// `android/app/src/main/kotlin/org/ippo/ippo/SystemTimeZone.kt`.
const MethodChannel _timeZoneChannel = MethodChannel('org.ippo.ippo/time_zone');

/// The IANA name of the device's time zone, or null if it cannot be
/// found. Not knowing it is not an error: events are then written
/// without it, and their offsets still give the exact moments.
Future<String?> readSystemTimeZone() async {
  if (Platform.isAndroid) {
    try {
      return _validZoneName(
        await _timeZoneChannel.invokeMethod<String>('timeZone'),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
  if (Platform.isLinux) {
    return _linuxTimeZone();
  }
  return null;
}

/// On Linux, the `TZ` setting if it names a zone, else where
/// `/etc/localtime` points: `/usr/share/zoneinfo/Europe/Paris` names
/// `Europe/Paris`.
String? _linuxTimeZone() {
  final fromSetting = _validZoneName(Platform.environment['TZ']);
  if (fromSetting != null) {
    return fromSetting;
  }
  try {
    final target = Link('/etc/localtime').targetSync();
    const marker = 'zoneinfo/';
    final start = target.indexOf(marker);
    if (start < 0) {
      return null;
    }
    return _validZoneName(target.substring(start + marker.length));
  } on FileSystemException {
    return null;
  }
}

/// [name] if it looks like an IANA zone name (`Europe/Paris`, `UTC`),
/// else null: never write something odd into the data.
String? _validZoneName(String? name) {
  if (name == null) {
    return null;
  }
  final pattern = RegExp(r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)*$');
  return pattern.hasMatch(name) ? name : null;
}
