// SPDX-License-Identifier: GPL-3.0-or-later

/// A data folder kept only in memory, for the demo.
library;

import 'dart:convert';

import 'data_folder.dart';

/// A [DataFolder] whose files live in memory and vanish when the app
/// closes or the demo ends. It never touches the disk, so the demo can
/// let people add, change and delete things freely without any risk to
/// real data.
class MemoryDataFolder implements DataFolder {
  /// Creates a folder holding [files]: each path (such as
  /// `events/<id>.jsonl`) with its text.
  MemoryDataFolder(Map<String, String> files) : _files = Map.of(files);

  final Map<String, String> _files;

  @override
  Future<List<String>> listFileNames(String folderPath) async {
    checkRelativePath(folderPath);
    final names = <String>{};
    for (final path in _files.keys) {
      final rest = _inside(folderPath, path);
      if (rest != null && !rest.contains('/')) {
        names.add(rest);
      }
    }
    return names.toList()..sort();
  }

  @override
  Future<List<String>> listFolderNames(String folderPath) async {
    checkRelativePath(folderPath);
    final names = <String>{};
    for (final path in _files.keys) {
      final rest = _inside(folderPath, path);
      if (rest != null && rest.contains('/')) {
        final name = rest.substring(0, rest.indexOf('/'));
        if (!name.startsWith('.')) {
          names.add(name);
        }
      }
    }
    return names.toList()..sort();
  }

  @override
  Future<String> readTextFile(String filePath) async {
    checkRelativePath(filePath);
    final text = _files[filePath];
    if (text == null) {
      throw DataFolderException('There is no file "$filePath".');
    }
    return text;
  }

  @override
  Future<void> appendToTextFile(String filePath, String text) async {
    checkRelativePath(filePath);
    _files[filePath] = (_files[filePath] ?? '') + text;
  }

  @override
  Future<void> deleteFile(String filePath) async {
    checkRelativePath(filePath);
    _files.remove(filePath);
  }

  @override
  Future<int> sizeInBytes(String path) async {
    checkRelativePath(path);
    var total = 0;
    for (final entry in _files.entries) {
      final isHidden = entry.key.split('/').any((part) => part.startsWith('.'));
      final isInside = entry.key == path || _inside(path, entry.key) != null;
      if (isInside && !isHidden) {
        total += utf8.encode(entry.value).length;
      }
    }
    return total;
  }

  /// The part of [path] after [folderPath] and a `/`, or null if [path]
  /// is not inside that folder.
  static String? _inside(String folderPath, String path) {
    final prefix = '$folderPath/';
    return path.startsWith(prefix) ? path.substring(prefix.length) : null;
  }
}
