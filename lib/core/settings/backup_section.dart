// SPDX-License-Identifier: GPL-3.0-or-later

/// The parts of the settings screen for backing up and restoring data,
/// and, separately, for clearing it.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../save_or_show_error.dart';
import '../widgets/section_card.dart';

/// "Back up now" and "Restore a backup". "Clear all data" is a card of
/// its own at the bottom of Settings ([ClearDataSection]), away from
/// these everyday buttons.
class BackupSection extends StatelessWidget {
  /// Creates the section.
  const BackupSection({super.key, required this.appState});

  /// The app-wide state, holding the data folder.
  final AppState appState;

  Future<void> _backUp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    String? folder;
    final saved = await saveOrShowError(context, () async {
      folder = await appState.backUpNow();
    });
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text('Backed up to $folder.')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var backups = <String>[];
    final listed = await saveOrShowError(context, () async {
      backups = await appState.manualBackups();
    });
    if (!listed || !context.mounted) {
      return;
    }
    if (backups.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('There are no backups yet.')),
      );
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => _RestoreDialog(backups: backups),
    );
    if (chosen == null || !context.mounted) {
      return;
    }
    var added = 0;
    final restored = await saveOrShowError(context, () async {
      added = await appState.restoreFrom(chosen);
    });
    if (restored) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Nothing to restore: every event in that backup is '
                      'already here.'
                : 'Restored $added ${added == 1 ? 'event' : 'events'}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (appState.dataFolder == null) {
      return const NoteText('Choose a data folder first.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoteText(
          'A backup copies every event file into a new folder inside '
          'backups. Copy the whole data folder elsewhere to keep it safe '
          'from this phone, too.',
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => _backUp(context),
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Back up now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _restore(context),
          icon: const Icon(Icons.settings_backup_restore),
          label: const Text('Restore a backup'),
        ),
      ],
    );
  }
}

/// "Clear all data", with a sentence saying what it does. It sits in its
/// own card at the very bottom of Settings, so it is never tapped by
/// mistake on the way to a backup.
class ClearDataSection extends StatelessWidget {
  /// Creates the section.
  const ClearDataSection({super.key, required this.appState});

  /// The app-wide state, holding the data folder.
  final AppState appState;

  Future<void> _clear(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber, color: colors.error),
        title: const Text('Clear all data?'),
        content: const Text(
          'This deletes every habit, food, exercise and sleep entry, from '
          'every device that uses this folder. Your sync tool will delete '
          'them on your other devices too.\n\n'
          'A backup of everything is made first, in the backups folder. '
          'To get the data back, use "Restore a backup".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Back up and clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    String? folder;
    final cleared = await saveOrShowError(context, () async {
      folder = await appState.clearAllData();
    });
    if (cleared) {
      messenger.showSnackBar(
        SnackBar(content: Text('Cleared. The backup is in $folder.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (appState.dataFolder == null) {
      return const NoteText('Choose a data folder first.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoteText(
          'Deletes every entry from every device using this folder, '
          'after making a backup. Restore a backup to get it back.',
        ),
        DeleteButton(label: 'Clear all data', onPressed: () => _clear(context)),
      ],
    );
  }
}

/// Asks which backup to restore, and says what restoring does. Pops
/// with the chosen backup's path, or null for Cancel.
class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.backups});

  /// The backup folders' paths, newest first.
  final List<String> backups;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  late String _chosen = widget.backups.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.settings_backup_restore),
      title: const Text('Restore a backup'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adds back every event in the backup that is missing now: '
              'habits, foods, meals, exercises, sleep and the rest. '
              'Nothing you have now is changed or deleted, so restoring '
              'twice is safe.',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: RadioGroup<String>(
                groupValue: _chosen,
                onChanged: (value) => setState(() => _chosen = value!),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final backup in widget.backups)
                      RadioListTile<String>(
                        value: backup,
                        contentPadding: EdgeInsets.zero,
                        title: Text(backupLabel(backup)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_chosen),
          child: const Text('Restore'),
        ),
      ],
    );
  }
}

/// A backup folder's path as a person reads it: for example
/// `backups/manual-2026-01-02-030405` becomes "2026-01-02 at 03:04:05".
/// Folder names in another shape are shown as they are.
String backupLabel(String backupFolder) {
  final name = backupFolder.split('/').last;
  final match = RegExp(r'^manual-(\d{4}-\d{2}-\d{2})-(\d{2})(\d{2})(\d{2})$')
      .firstMatch(name);
  if (match == null) {
    return name;
  }
  return '${match[1]} at ${match[2]}:${match[3]}:${match[4]}';
}
