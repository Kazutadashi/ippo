// SPDX-License-Identifier: GPL-3.0-or-later

/// The part of the settings screen for backing up and clearing data.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../save_or_show_error.dart';
import '../widgets/section_card.dart';

/// "Back up now" and "Clear all data".
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
          'To get the data back, copy those files into the events folder.',
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
        DeleteButton(label: 'Clear all data', onPressed: () => _clear(context)),
      ],
    );
  }
}
