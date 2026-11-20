// SPDX-License-Identifier: GPL-3.0-or-later

/// The entry point of the Ippo app.
///
/// It finds the settings file, starts the app, then loads the settings
/// and the data folder in the background.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app_state.dart';
import 'core/dates.dart';
import 'core/home_screen.dart';
import 'core/storage/data_folder.dart';
import 'core/storage/settings_file.dart';
import 'core/system_colors.dart';
import 'core/theme.dart';
import 'core/units.dart';

/// Starts the app.
Future<void> main() async {
  // Needed before talking to Android (to find the settings folder).
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the system navigation bar, so the app's own colours run
  // to the bottom edge instead of stopping at a black band.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
    systemAccentColor: await readSystemAccentColor(),
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
class IppoApp extends StatefulWidget {
  /// Creates the root widget, showing [appState].
  const IppoApp({super.key, required this.appState});

  /// The app-wide state, shared by every screen.
  final AppState appState;

  @override
  State<IppoApp> createState() => _IppoAppState();
}

class _IppoAppState extends State<IppoApp> {
  late final AppLifecycleListener _lifecycle;

  // The themes built last, and what they were built from. Building a
  // theme takes a moment, so it is only done again when the colour or
  // mode changes, not on every save.
  String? _themeKey;
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  @override
  void initState() {
    super.initState();
    // Coming back to the app: read the data folder again, so entries
    // synced from other devices show without doing anything.
    _lifecycle = AppLifecycleListener(onResume: widget.appState.reloadEvents);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _updateThemes() {
    final saved = widget.appState.settings?.accentColor;
    final system = widget.appState.systemAccentColor;
    final accent = chooseAccentColor(saved, system);
    final matchSystem = usesSystemAccent(saved, system);
    final trueBlack = widget.appState.settings?.usesTrueBlack ?? false;
    final key = '${accent.toARGB32()} $matchSystem $trueBlack';
    if (key == _themeKey) {
      return;
    }
    _themeKey = key;
    _lightTheme = buildTheme(
      accent,
      Brightness.light,
      matchSystem: matchSystem,
    );
    _darkTheme = buildTheme(
      accent,
      Brightness.dark,
      matchSystem: matchSystem,
      trueBlack: trueBlack,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Redraw when the settings change, so a new theme or accent colour
    // shows at once.
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        _updateThemes();
        final uses12Hours = widget.appState.settings?.uses12HourClock ?? false;
        // Every screen shows times in the chosen style (see dates.dart).
        showTimesIn24Hours = !uses12Hours;
        // Body measurements in the chosen units (see units.dart).
        showImperialUnits =
            widget.appState.settings?.usesImperialUnits ?? false;
        return MaterialApp(
          title: 'Ippo',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: parseThemeMode(widget.appState.settings?.themeMode),
          // The pickers' language. Both read dates as "Wed 18 Nov", as
          // the app writes them, and start weeks on Monday. British
          // English has a 24-hour clock picker; Australian English the
          // same with a 12-hour one. The app's text is English either way.
          locale: uses12Hours ? _englishWith12Hours : _englishWith24Hours,
          supportedLocales: const [_englishWith24Hours, _englishWith12Hours],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(alwaysUse24HourFormat: !uses12Hours),
            // A clear system navigation bar, with icons that suit the
            // current light or dark theme.
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: _systemBarsFor(Theme.of(context).brightness),
              child: child!,
            ),
          ),
          home: HomeScreen(appState: widget.appState),
        );
      },
    );
  }
}

/// The pickers' language with a 24-hour clock.
const Locale _englishWith24Hours = Locale('en', 'GB');

/// The pickers' language with a 12-hour clock.
const Locale _englishWith12Hours = Locale('en', 'AU');

/// See-through system bars, with dark icons on a light theme and light
/// icons on a dark one.
SystemUiOverlayStyle _systemBarsFor(Brightness brightness) {
  final iconBrightness = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarContrastEnforced: false,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
  );
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
