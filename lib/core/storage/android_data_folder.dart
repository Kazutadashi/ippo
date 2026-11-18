// SPDX-License-Identifier: GPL-3.0-or-later

/// A data folder on Android, reached through the system folder picker.
library;

import 'package:flutter/services.dart';

import 'data_folder.dart';

/// The channel to the Kotlin half of the storage code.
///
/// Its name must match `StorageBridge.CHANNEL_NAME` in
/// `android/app/src/main/kotlin/org/ippo/ippo/StorageBridge.kt`.
const MethodChannel _storageChannel = MethodChannel('org.ippo.ippo/storage');

/// A [DataFolder] on Android.
///
/// Android does not let apps open shared folders with normal file paths.
/// Instead the user picks a folder with [pickAndroidFolder], and Android
/// grants access to that one folder only. The actual file work happens in
/// Kotlin (`StorageBridge.kt`); this class only forwards the calls.
class AndroidDataFolder implements DataFolder {
  /// Creates a data folder from the folder URI that [pickAndroidFolder]
  /// returned.
  AndroidDataFolder(this.folderUri);

  /// Android's identifier for the chosen folder, a `content://` URI.
  final String folderUri;

  @override
  Future<List<String>> listFileNames(String folderPath) async {
    checkRelativePath(folderPath);
    final names = await _call<List<Object?>>('listFiles', {'path': folderPath});
    final fileNames = names.whereType<String>().toList();
    fileNames.sort();
    return fileNames;
  }

  @override
  Future<String> readTextFile(String filePath) async {
    checkRelativePath(filePath);
    return _call<String>('readText', {'path': filePath});
  }

  @override
  Future<void> appendToTextFile(String filePath, String text) async {
    checkRelativePath(filePath);
    await _call<Object?>('appendText', {'path': filePath, 'text': text});
  }

  /// Calls a Kotlin method and turns its errors into [DataFolderException].
  Future<T> _call<T>(String method, Map<String, String> arguments) async {
    try {
      final answer = await _storageChannel.invokeMethod<T>(method, {
        'folderUri': folderUri,
        ...arguments,
      });
      return answer as T;
    } on PlatformException catch (error) {
      throw DataFolderException(error.message ?? error.code);
    }
  }
}

/// Returns the data folder the user chose earlier, or null if there is none.
///
/// Android remembers which folder the app was given access to, so this
/// works after the app restarts without the app storing anything itself.
/// Throws [DataFolderException] on failure.
Future<String?> savedAndroidFolder() async {
  try {
    return await _storageChannel.invokeMethod<String>('savedFolder');
  } on PlatformException catch (error) {
    throw DataFolderException(error.message ?? error.code);
  }
}

/// Opens Android's folder picker so the user can choose the data folder.
///
/// Returns the chosen folder's URI, or null if the user cancelled.
/// Android remembers the permission, so the same folder keeps working
/// after the app restarts. Throws [DataFolderException] on failure.
Future<String?> pickAndroidFolder() async {
  try {
    return await _storageChannel.invokeMethod<String>('pickFolder');
  } on PlatformException catch (error) {
    throw DataFolderException(error.message ?? error.code);
  }
}
