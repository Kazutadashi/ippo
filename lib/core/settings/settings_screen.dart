// SPDX-License-Identifier: GPL-3.0-or-later

/// The settings screen: data folder, appearance, this device's name, and
/// the list of devices with when each was last seen.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            if (appState.errorMessage != null)
              _ErrorBanner(message: appState.errorMessage!),
            const _SectionTitle('Data folder'),
            const Text(
              'Ippo keeps all your data as plain text files in this folder. '
              'To use several devices, sync this folder between them, for '
              'example with Syncthing.',
            ),
            const SizedBox(height: 8),
            _DataFolderSection(appState: appState),
            const _SectionTitle('Appearance'),
            AppearanceSection(appState: appState),
            const _SectionTitle('This device'),
            _DeviceNameSection(appState: appState),
            const _SectionTitle('Devices'),
            DevicesSection(appState: appState),
          ],
        ),
      ),
    );
  }
}

/// Shows the data folder and lets the user choose one.
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
    final description = appState.dataFolderDescription ?? 'None chosen yet.';

    if (appState.isAndroid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current folder: $description'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: appState.chooseAndroidDataFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose folder'),
          ),
        ],
      );
    }

    // On Linux, the user types or pastes the folder's path.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current folder: $description'),
        const SizedBox(height: 8),
        TextField(
          controller: _pathField,
          decoration: InputDecoration(
            labelText: 'Folder path, for example /path/to/data',
            errorText: _problem,
          ),
          onSubmitted: (_) => _useTypedPath(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _useTypedPath,
          icon: const Icon(Icons.folder_open),
          label: const Text('Use this folder'),
        ),
      ],
    );
  }
}

/// Lets the user rename this device and shows its id.
class _DeviceNameSection extends StatefulWidget {
  const _DeviceNameSection({required this.appState});

  final AppState appState;

  @override
  State<_DeviceNameSection> createState() => _DeviceNameSectionState();
}

class _DeviceNameSectionState extends State<_DeviceNameSection> {
  late final TextEditingController _nameField = TextEditingController(
    text: widget.appState.settings?.deviceName ?? '',
  );
  String? _problem;
  bool _isSaved = false;

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final problem = await widget.appState.renameDevice(_nameField.text);
    setState(() {
      _problem = problem;
      _isSaved = problem == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = widget.appState.settings?.deviceId ?? 'unknown';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameField,
          decoration: InputDecoration(
            labelText: 'Device name, shown next to its data',
            errorText: _problem,
            helperText: _isSaved ? 'Saved.' : null,
          ),
          onChanged: (_) => setState(() => _isSaved = false),
          onSubmitted: (_) => _saveName(),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveName, child: const Text('Save name')),
        const SizedBox(height: 8),
        SelectableText(
          'Device id: $deviceId\n'
          'This device writes its events to events/$deviceId.jsonl.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A heading between the sections of the screen.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}
