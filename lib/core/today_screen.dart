// SPDX-License-Identifier: GPL-3.0-or-later

/// The home tab: today's date and one card per module saying what was
/// logged today.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'module.dart';

/// The home tab. Tapping a module's card opens that module's tab.
class TodayScreen extends StatelessWidget {
  /// Creates the home tab.
  const TodayScreen({
    super.key,
    required this.appState,
    required this.onOpenModule,
  });

  /// The app-wide state.
  final AppState appState;

  /// Called with the module whose card was tapped.
  final ValueChanged<IppoModule> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          children: [
            Text(
              describeToday(DateTime.now()),
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            for (final module in allModules)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Icon(module.icon),
                  ),
                  title: Text(module.title, style: textTheme.titleMedium),
                  subtitle: Text(module.summarizeToday(appState)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenModule(module),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Writes a day for the heading, for example `Tuesday, 18 November`.
String describeToday(DateTime day) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';
}
