// SPDX-License-Identifier: GPL-3.0-or-later

/// The settings screen: data folder, appearance, this device, and the
/// list of devices with when each was last seen.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../widgets/section_card.dart';
import 'appearance_section.dart';
import 'devices_section.dart';

/// The settings screen.
class SettingsScreen extends StatelessWidget {
  /// Creates the settings screen for [appState].
  const SettingsScreen({super.key, required this.appState});

  /// The app-wide state to show and change.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Rebuild whenever the app state changes, for example after the
      // data folder was read again.
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (appState.errorMessage != null)
              _ErrorBanner(message: appState.errorMessage!),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.folder, title: 'Data folder'),
                const SizedBox(height: 4),
                _DataFolderSection(appState: appState),
              ],
            ),
            SectionCard(
              children: [
                const CardHeader(icon: Icons.palette, title: 'Appearance'),
                const SizedBox(height: 4),
                AppearanceSection(appState: appState),
              ],
            ),
            SectionCard(
              children: [
                CardHeader(
                  icon: Icons.smartphone,
                  title: 'This device',
                  action: appState.settings == null
                      ? null
                      : HeaderEditButton(
                          onPressed: () => _renameDevice(context),
                        ),
                ),
                const SizedBox(height: 4),
                _ThisDeviceSection(appState: appState),
              ],
            ),
            SectionCard(
              children: [
                CardHeader(
                  icon: Icons.devices,
                  title: 'Devices',
                  action: appState.dataFolder == null
                      ? null
                      : TextButton.icon(
                          onPressed: appState.reloadEvents,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                ),
                const SizedBox(height: 4),
                DevicesSection(appState: appState),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Asks for a new device name, then saves it. A problem (such as an
  /// empty name) is shown at the bottom of the screen.
  Future<void> _renameDevice(BuildContext context) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameDialog(currentName: appState.settings?.deviceName ?? ''),
    );
    if (newName == null) {
      return;
    }
    final problem = await appState.renameDevice(newName);
    if (problem != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not saved: $problem')));
    }
  }
}

/// Shows the data folder and lets the user choose another one.
class _DataFolderSection extends StatefulWidget {
  const _DataFolderSection({required this.appState});

  final AppState appState;

  @override
  State<_DataFolderSection> createState() => _DataFolderSectionState();
}

class _DataFolderSectionState extends State<_DataFolderSection> {
  late final TextEditingController _pathField = TextEditingController(
    text: widget.appState.settings?.linuxDataFolderPath ?? '',
  );
  String? _problem;

  @override
  void dispose() {
    _pathField.dispose();
    super.dispose();
  }

  Future<void> _useTypedPath() async {
    final problem = await widget.appState.chooseLinuxDataFolder(
      _pathField.text,
    );
    setState(() => _problem = problem);
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final hasFolder = appState.dataFolderDescription != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoText(
          label: 'Current folder',
          text: appState.dataFolderDescription ?? 'None chosen yet',
        ),
        const SizedBox(height: 8),
        const NoteText(
          'Your data is saved here as plain text files. Sync this folder '
          'to use Ippo on several devices.',
        ),
        const SizedBox(height: 16),
        // On Linux, the user types or pastes the folder's path.
        if (!appState.isAndroid) ...[
          TextField(
            controller: _pathField,
            decoration: InputDecoration(
              labelText: 'Folder path, for example /path/to/data',
              errorText: _problem,
            ),
            onSubmitted: (_) => _useTypedPath(),
          ),
          const SizedBox(height: 12),
        ],
        // The main button the first time. Once a folder is in use,
        // changing it is rare, so the button is quieter.
        if (hasFolder)
          FilledButton.tonalIcon(
            onPressed: appState.isAndroid
                ? appState.chooseAndroidDataFolder
                : _useTypedPath,
            icon: const Icon(Icons.folder_open),
            label: Text(
              appState.isAndroid ? 'Change folder' : 'Use this folder instead',
            ),
          )
        else
          FilledButton.icon(
            onPressed: appState.isAndroid
                ? appState.chooseAndroidDataFolder
                : _useTypedPath,
            icon: const Icon(Icons.folder_open),
            label: Text(
              appState.isAndroid ? 'Choose folder' : 'Use this folder',
            ),
          ),
        if (hasFolder) ...[
          const SizedBox(height: 8),
          const NoteText(
            'Changing the folder moves nothing: the current folder keeps '
            'all its files.',
          ),
        ],
      ],
    );
  }
}

/// This device's name, id and event file, as information.
class _ThisDeviceSection extends StatelessWidget {
  const _ThisDeviceSection({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final settings = appState.settings;
    if (settings == null) {
      return const NoteText('Settings could not be loaded.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoText(label: 'Name', text: settings.deviceName),
        const SizedBox(height: 12),
        InfoText(
          label: 'Event file',
          text: 'events/${settings.deviceId}.jsonl',
          isSelectable: true,
          isSmallPrint: true,
        ),
      ],
    );
  }
}

/// A small window for typing a new device name. Closes with the name, or
/// with nothing if cancelled.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.currentName,
  );

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Device name'),
      content: TextField(
        controller: _nameField,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          helperText: 'Shown next to this device\'s data.',
        ),
        onSubmitted: (name) => Navigator.of(context).pop(name),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_nameField.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A box at the top of the screen showing the latest error.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}
