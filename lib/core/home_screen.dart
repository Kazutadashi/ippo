// SPDX-License-Identifier: GPL-3.0-or-later

/// The first screen of the app.
///
/// It lists the modules from `lib/modules/all_modules.dart`, and leads to
/// the settings.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'module.dart';
import 'settings/settings_screen.dart';

/// The home screen.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen for [appState].
  const HomeScreen({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(appState: appState),
      ),
    );
  }

  void _openModule(BuildContext context, IppoModule module) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => module.buildScreen(appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ippo'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildMessage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    if (appState.isLoading) {
      return const CircularProgressIndicator();
    }
    if (appState.dataFolder == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Welcome to Ippo. To start, choose the folder where your data '
            'will be kept.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _openSettings(context),
            child: const Text('Choose a data folder'),
          ),
        ],
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final module in allModules)
          Card(
            child: ListTile(
              leading: Icon(module.icon),
              title: Text(module.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openModule(context, module),
            ),
          ),
      ],
    );
  }
}
