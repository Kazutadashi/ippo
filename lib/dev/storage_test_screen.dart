// SPDX-License-Identifier: GPL-3.0-or-later

/// A temporary screen for trying out the storage code on a real device.
///
/// It lets a developer pick a data folder, append a test line to
/// `events/storage-test.jsonl`, and read back every file in `events/`.
/// It will be removed once the real settings screen exists.
library;

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../core/storage/android_data_folder.dart';
import '../core/storage/data_folder.dart';
import '../core/storage/local_data_folder.dart';

/// The temporary storage test screen.
class StorageTestScreen extends StatefulWidget {
  /// Creates the screen.
  const StorageTestScreen({super.key});

  @override
  State<StorageTestScreen> createState() => _StorageTestScreenState();
}

class _StorageTestScreenState extends State<StorageTestScreen> {
  final TextEditingController _linuxPathField = TextEditingController();
  DataFolder? _dataFolder;
  String _output = 'No folder chosen yet.';

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _loadSavedFolder();
    }
  }

  Future<void> _loadSavedFolder() async {
    await _runAndShow(() async {
      final folderUri = await savedAndroidFolder();
      if (folderUri == null) {
        return 'No folder chosen yet.';
      }
      _dataFolder = AndroidDataFolder(folderUri);
      return 'Using saved folder: $folderUri';
    });
  }

  @override
  void dispose() {
    _linuxPathField.dispose();
    super.dispose();
  }

  Future<void> _chooseFolder() async {
    if (!Platform.isAndroid) {
      setState(() {
        _dataFolder = LocalDataFolder(_linuxPathField.text.trim());
        _output = 'Using folder: ${_linuxPathField.text.trim()}';
      });
      return;
    }
    await _runAndShow(() async {
      final folderUri = await pickAndroidFolder();
      if (folderUri == null) {
        return 'Cancelled.';
      }
      _dataFolder = AndroidDataFolder(folderUri);
      return 'Using folder: $folderUri';
    });
  }

  Future<void> _appendTestLine(DataFolder dataFolder) async {
    await _runAndShow(() async {
      final line = jsonEncode({
        'test': 'storage',
        'written_at': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      });
      await dataFolder.appendToTextFile('events/storage-test.jsonl', '$line\n');
      return 'Appended:\n$line';
    });
  }

  Future<void> _readAllFiles(DataFolder dataFolder) async {
    await _runAndShow(() async {
      final fileNames = await dataFolder.listFileNames('events');
      if (fileNames.isEmpty) {
        return 'No files in events/ yet.';
      }
      final report = StringBuffer();
      for (final name in fileNames) {
        final text = await dataFolder.readTextFile('events/$name');
        report.writeln('== events/$name');
        report.writeln(text);
      }
      return report.toString();
    });
  }

  /// Runs [action] and shows its result, or its error, on screen.
  Future<void> _runAndShow(Future<String> Function() action) async {
    String message;
    try {
      message = await action();
    } on DataFolderException catch (error) {
      message = 'Error: ${error.message}';
    }
    setState(() => _output = message);
  }

  @override
  Widget build(BuildContext context) {
    final dataFolder = _dataFolder;
    return Scaffold(
      appBar: AppBar(title: const Text('Ippo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Storage test (temporary developer screen)'),
          const SizedBox(height: 12),
          if (!Platform.isAndroid)
            TextField(
              controller: _linuxPathField,
              decoration: const InputDecoration(
                labelText: 'Data folder path, for example /path/to/data',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _chooseFolder,
            child: const Text('Choose data folder'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: dataFolder == null
                ? null
                : () => _appendTestLine(dataFolder),
            child: const Text('Append test line'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: dataFolder == null
                ? null
                : () => _readAllFiles(dataFolder),
            child: const Text('Read all files in events/'),
          ),
          const SizedBox(height: 16),
          SelectableText(_output),
        ],
      ),
    );
  }
}
