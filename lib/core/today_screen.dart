// SPDX-License-Identifier: GPL-3.0-or-later

/// The home tab: a greeting, the date, and one card per module with the
/// most important facts about today.
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
            for (final module in allModules)
              _ModuleTodayCard(
                module: module,
                facts: module.todayFacts(appState, DateTime.now()),
                onOpen: () => onOpenModule(module),
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

/// One module's card on the home screen: its name, and its facts about
/// today as plain information. Tapping it opens the module.
class _ModuleTodayCard extends StatelessWidget {
  const _ModuleTodayCard({
    required this.module,
    required this.facts,
    required this.onOpen,
  });

  final IppoModule module;
  final List<TodayFact> facts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onOpen,
      children: [
        CardHeader(
          icon: module.icon,
          title: module.title,
          action: HeaderOpenButton(onPressed: onOpen),
        ),
        const SizedBox(height: 4),
        if (facts.isEmpty)
          const NoteText('Nothing logged yet today.')
        else
          InfoRow(
            // Three columns on every card, so the facts line up.
            columns: 3,
            values: [
              for (final fact in facts)
                InfoValue(label: fact.label, value: fact.value),
            ],
          ),
      ],
    );
  }
}
