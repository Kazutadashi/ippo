// SPDX-License-Identifier: GPL-3.0-or-later

/// The entry point of the Ippo app.
///
/// It finds the settings file, starts the app, then loads the settings
/// and the data folder in the background.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'core/app_state.dart';
import 'core/home_screen.dart';
import 'core/storage/data_folder.dart';
import 'core/storage/settings_file.dart';

/// Starts the app.
Future<void> main() async {
  // Needed before talking to Android (to find the settings folder).
  WidgetsFlutterBinding.ensureInitialized();

  final SettingsFile settingsFile;
  try {
    settingsFile = await SettingsFile.forThisPlatform();
  } on DataFolderException catch (error) {
    runApp(StartupErrorApp(message: error.message));
    return;
  }

  final appState = AppState(
    settingsFile: settingsFile,
    isAndroid: Platform.isAndroid,
    defaultDeviceName: _defaultDeviceName(),
  );
  runApp(IppoApp(appState: appState));
  await appState.load();
}

/// A first guess at this device's name, which the user can change in
/// settings. It stays on this device and in the user's own data.
String _defaultDeviceName() {
  if (Platform.isAndroid) {
    return 'Android device';
  }
  return Platform.localHostname;
}

/// The root widget of the app.
class IppoApp extends StatelessWidget {
  /// Creates the root widget, showing [appState].
  const IppoApp({super.key, required this.appState});

  /// The app-wide state, shared by every screen.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ippo',
      home: HomeScreen(appState: appState),
    );
  }
}

/// Shown instead of the app if it cannot even find its settings folder.
class StartupErrorApp extends StatelessWidget {
  /// Creates the error screen with [message].
  const StartupErrorApp({super.key, required this.message});

  /// What went wrong.
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ippo',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ippo could not start.\n\n$message'),
          ),
        ),
      ),
    );
  }
}
