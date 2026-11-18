// SPDX-License-Identifier: GPL-3.0-or-later

/// A data folder on the local file system, used on Linux desktop.
library;

import 'dart:convert';
import 'dart:io';

import 'data_folder.dart';

/// A [DataFolder] that uses ordinary files through `dart:io`.
///
/// Used on Linux. Android does not allow this for shared folders, so it
/// uses `AndroidDataFolder` instead.
class LocalDataFolder implements DataFolder {
  /// Creates a data folder rooted at [rootPath], an absolute path the user
  /// chose.
  LocalDataFolder(this.rootPath);

  /// The absolute path of the data folder.
  final String rootPath;

  @override
  Future<List<String>> listFileNames(String folderPath) async {
    checkRelativePath(folderPath);
    final folder = Directory(_fullPath(folderPath));
    if (!folder.existsSync()) {
      return [];
    }
    try {
      final names = <String>[];
      for (final entry in folder.listSync(followLinks: false)) {
        if (entry is File) {
          names.add(entry.uri.pathSegments.last);
        }
      }
      names.sort();
      return names;
    } on FileSystemException catch (error) {
      throw DataFolderException(
        'Could not list "$folderPath": ${error.message}',
      );
    }
  }

  @override
  Future<String> readTextFile(String filePath) async {
    checkRelativePath(filePath);
    try {
      return await File(_fullPath(filePath)).readAsString(encoding: utf8);
    } on FileSystemException catch (error) {
      throw DataFolderException('Could not read "$filePath": ${error.message}');
    }
  }

  @override
  Future<void> appendToTextFile(String filePath, String text) async {
    checkRelativePath(filePath);
    final file = File(_fullPath(filePath));
    try {
      await file.parent.create(recursive: true);
      // FileMode.append only ever adds to the end of the file.
      // flush: true waits until the operating system has the data.
      await file.writeAsString(
        text,
        mode: FileMode.append,
        encoding: utf8,
        flush: true,
      );
    } on FileSystemException catch (error) {
      throw DataFolderException(
        'Could not write "$filePath": ${error.message}',
      );
    }
  }

  /// Checks a data folder path the user typed.
  ///
  /// Returns null if [path] is an absolute path to an existing folder,
  /// or a message explaining what is wrong.
  static String? checkFolderPath(String path) {
    if (!path.startsWith('/')) {
      return 'Please enter a full path, starting with /.';
    }
    if (!Directory(path).existsSync()) {
      return 'There is no folder at $path.';
    }
    return null;
  }

  /// Joins the data folder path and a relative path checked beforehand.
  String _fullPath(String relativePath) => '$rootPath/$relativePath';
}
