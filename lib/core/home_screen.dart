// SPDX-License-Identifier: GPL-3.0-or-later

/// The app's main screen: a bar at the bottom with one tab per module,
/// plus settings.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'settings/settings_screen.dart';

/// The name used to remember that the settings tab was open.
const String settingsScreenName = 'settings';

/// The main screen. Each module from `lib/modules/all_modules.dart` gets
/// a tab, and the last tab is settings.
///
/// The app opens on the tab that was open last time, so logging
/// something takes no extra taps. Every tab keeps its state (for example
/// the day shown) while another tab is open.
class HomeScreen extends StatefulWidget {
  /// Creates the main screen for [appState].
  const HomeScreen({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The open tab, or null until the settings have loaded and the
  /// starting tab is known.
  int? _selectedTab;

  /// The tab names in order: each module's name, then settings.
  List<String> get _tabNames => [
    for (final module in allModules) module.moduleName,
    settingsScreenName,
  ];

  /// The tab to start on: the one open last time, or settings if there
  /// is no data folder yet (the user has to choose one first).
  int _startingTab() {
    final settingsTab = _tabNames.length - 1;
    if (widget.appState.dataFolder == null) {
      return settingsTab;
    }
    final lastIndex = _tabNames.indexOf(
      widget.appState.settings?.lastScreen ?? '',
    );
    return lastIndex < 0 ? 0 : lastIndex;
  }

  void _openTab(int index) {
    setState(() => _selectedTab = index);
    widget.appState.rememberScreen(_tabNames[index]);
  }

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
        final selectedTab = _selectedTab ??= _startingTab();
        return Scaffold(
          // IndexedStack keeps every tab alive, so each keeps its state.
          body: IndexedStack(
            index: selectedTab,
            children: [
              for (final module in allModules)
                widget.appState.dataFolder == null
                    ? _ChooseDataFolderFirst(
                        onOpenSettings: () => _openTab(_tabNames.length - 1),
                      )
                    : module.buildScreen(widget.appState),
              SettingsScreen(appState: widget.appState),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedTab,
            onDestinationSelected: _openTab,
            destinations: [
              for (final module in allModules)
                NavigationDestination(
                  icon: Icon(module.icon),
                  label: module.title,
                ),
              const NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown in a module's tab while no data folder is chosen.
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
