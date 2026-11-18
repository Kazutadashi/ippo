// SPDX-License-Identifier: GPL-3.0-or-later

/// The app's frame: a bar at the bottom with Home and one tab per
/// module. Settings opens from a gear on Home.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'settings/settings_screen.dart';
import 'today_screen.dart';

/// The app's frame. The tabs are, in order: Home, then each module from
/// `lib/modules/all_modules.dart`. Android recommends at most five tabs,
/// so Settings is not one; it opens from Home.
///
/// The app opens on Home. Every tab keeps its state (for example the day
/// shown) while another tab is open.
class HomeScreen extends StatefulWidget {
  /// Creates the frame for [appState].
  const HomeScreen({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The open tab: 0 is Home, 1 the first module, and so on.
  int _selectedTab = 0;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(appState: widget.appState),
      ),
    );
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
        final hasDataFolder = widget.appState.dataFolder != null;
        final chooseFolderFirst = _ChooseDataFolderFirst(
          onOpenSettings: _openSettings,
        );
        return Scaffold(
          // IndexedStack keeps every tab alive, so each keeps its state.
          body: IndexedStack(
            index: _selectedTab,
            children: [
              hasDataFolder
                  ? TodayScreen(
                      appState: widget.appState,
                      onOpenSettings: _openSettings,
                    )
                  : chooseFolderFirst,
              for (final module in allModules)
                hasDataFolder
                    ? module.buildScreen(widget.appState)
                    : chooseFolderFirst,
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) =>
                setState(() => _selectedTab = index),
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
            ],
          ),
        );
      },
    );
  }
}

/// Shown while no data folder is chosen, leading to Settings.
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
