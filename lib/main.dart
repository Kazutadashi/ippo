// SPDX-License-Identifier: GPL-3.0-or-later

/// The entry point of the Ippo app.
///
/// For now this only shows a temporary storage test screen. The core services
/// (storage, settings, navigation) and the modules (habits,
/// calisthenics, meals) will be added step by step.
library;

import 'package:material_ui/material_ui.dart';

import 'dev/storage_test_screen.dart';

/// Starts the app.
void main() {
  runApp(const IppoApp());
}

/// The root widget of the app.
///
/// It sets up the app-wide theme and shows the first screen.
class IppoApp extends StatelessWidget {
  /// Creates the root widget.
  const IppoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Ippo', home: StorageTestScreen());
  }
}
