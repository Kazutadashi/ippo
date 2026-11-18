// SPDX-License-Identifier: GPL-3.0-or-later

/// The home tab: today's date and one card per module saying what was
/// logged today.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'module.dart';
import 'widgets/section_card.dart';

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
            Text(greetingFor(DateTime.now()), style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              describeToday(DateTime.now()),
              style: textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            NoteText(describeWhatIsLogged(appState)),
            const SizedBox(height: 12),
            for (final module in allModules)
              Card(
                // The same spacing as cards on every other screen.
                margin: const EdgeInsets.only(top: 12),
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

/// A greeting for the time of day: `Good morning`, `Good afternoon` or
/// `Good evening`.
String greetingFor(DateTime moment) {
  if (moment.hour < 12) {
    return 'Good morning';
  }
  if (moment.hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

/// Says which modules have something logged today and which do not, for
/// example `Logged today: Food. Still to log: Exercise, Sleep.`
String describeWhatIsLogged(AppState appState) {
  final logged = <String>[];
  final notLogged = <String>[];
  for (final module in allModules) {
    if (module.hasLoggedToday(appState)) {
      logged.add(module.title);
    } else {
      notLogged.add(module.title);
    }
  }
  if (notLogged.isEmpty) {
    return 'Everything is logged for today.';
  }
  if (logged.isEmpty) {
    return 'Nothing logged yet today.';
  }
  return 'Logged today: ${logged.join(', ')}. '
      'Still to log: ${notLogged.join(', ')}.';
}
