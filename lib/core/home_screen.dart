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
          onTryDemo: () => startDemo(widget.appState),
        );
        // IndexedStack keeps every tab alive, so each keeps its state.
        final tabs = IndexedStack(
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
        );
        // While the demo runs, a strip above the tabs says so on every
        // screen, with the way out.
        final demoStrip = widget.appState.isDemo
            ? _DemoStrip(onLeave: widget.appState.endDemo)
            : null;
        final destinations = [
          (const Icon(Icons.home_outlined), 'Home'),
          for (final module in allModules) (module.buildIcon(), module.title),
        ];
        // On a wide window (a desktop or a tablet on its side), the tabs
        // go down the left side, and screens keep a readable width
        // instead of stretching across the whole window.
        if (MediaQuery.sizeOf(context).width >= _wideWindow) {
          return Scaffold(
            bottomNavigationBar: demoStrip,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedTab = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (icon, label) in destinations)
                      NavigationRailDestination(icon: icon, label: Text(label)),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: tabs,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final navigationBar = NavigationBar(
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
                icon: module.buildIcon(),
                label: module.title,
              ),
          ],
        );
        return Scaffold(
          body: tabs,
          bottomNavigationBar: demoStrip == null
              ? navigationBar
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [demoStrip, navigationBar],
                ),
        );
      },
    );
  }
}

/// From this width on (in logical pixels), the tabs move to the side.
/// It is Material's "expanded" window size.
const double _wideWindow = 840;

/// The widest a screen gets on a wide window, so lines stay readable.
const double _maxWidth = 720;

/// Shown while no data folder is chosen, leading to Settings.
class _ChooseDataFolderFirst extends StatelessWidget {
  const _ChooseDataFolderFirst({
    required this.onOpenSettings,
    required this.onTryDemo,
  });

  final VoidCallback onOpenSettings;

  /// Starts the demo, to look around before choosing a folder.
  final VoidCallback onTryDemo;

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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onTryDemo,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Or try the demo first'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The strip shown above the tabs during the demo: a quiet line saying
/// what it is, and a small button to leave. It uses the bar's own colours
/// and small text, so it does not pull the eye (screen recordings of the
/// demo stay about the app, not the strip).
class _DemoStrip extends StatelessWidget {
  const _DemoStrip({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.labelMedium;
    return Material(
      // The navigation bar's colour, so the two read as one.
      color:
          theme.navigationBarTheme.backgroundColor ??
          theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Demo data, not saved',
                style: small?.copyWith(color: muted),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: muted,
                textStyle: small,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(48, 32),
              ),
              onPressed: onLeave,
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }
}
