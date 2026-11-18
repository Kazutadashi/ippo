// SPDX-License-Identifier: GPL-3.0-or-later

/// The app's frame: a bar at the bottom with Home, one tab per module,
/// and Settings.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'settings/settings_screen.dart';
import 'today_screen.dart';

/// The app's frame. The tabs are, in order: Home, each module from
/// `lib/modules/all_modules.dart`, and Settings.
///
/// The app opens on Home, or on Settings if no data folder is chosen
/// yet. Every tab keeps its state (for example the day shown) while
/// another tab is open.
class HomeScreen extends StatefulWidget {
  /// Creates the frame for [appState].
  const HomeScreen({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The tab of the first module: Home comes before the modules.
  static const int _firstModuleTab = 1;

  /// The Settings tab, after every module.
  int get _settingsTab => _firstModuleTab + allModules.length;

  /// The open tab, or null until the settings have loaded and the
  /// starting tab is known.
  int? _selectedTab;

  void _openTab(int index) => setState(() => _selectedTab = index);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        if (widget.appState.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final hasDataFolder = widget.appState.dataFolder != null;
        // A new user must choose a data folder first, in Settings.
        final selectedTab = _selectedTab ??= hasDataFolder ? 0 : _settingsTab;
        return Scaffold(
          // IndexedStack keeps every tab alive, so each keeps its state.
          body: IndexedStack(
            index: selectedTab,
            children: [
              hasDataFolder
                  ? TodayScreen(appState: widget.appState)
                  : _ChooseDataFolderFirst(
                      onOpenSettings: () => _openTab(_settingsTab),
                    ),
              for (final module in allModules)
                hasDataFolder
                    ? module.buildScreen(widget.appState)
                    : _ChooseDataFolderFirst(
                        onOpenSettings: () => _openTab(_settingsTab),
                      ),
              SettingsScreen(appState: widget.appState),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedTab,
            onDestinationSelected: _openTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              for (final module in allModules)
                NavigationDestination(
                  icon: Icon(module.icon),
                  label: module.title,
                ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown in the Home and module tabs while no data folder is chosen.
class _ChooseDataFolderFirst extends StatelessWidget {
  const _ChooseDataFolderFirst({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome to Ippo. To start, choose the folder where your '
                'data will be kept.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onOpenSettings,
                child: const Text('Choose a data folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
