// SPDX-License-Identifier: GPL-3.0-or-later

/// The home tab: a quick glance at the day so far.
///
/// Like a weather app, it is information: a greeting, the date, and a
/// grid of tiles from every module. The bar at the bottom leads to each
/// module; the only thing to tap here is the gear for Settings.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'module.dart';
import 'widgets/section_card.dart';

/// The home tab.
class TodayScreen extends StatelessWidget {
  /// Creates the home tab.
  const TodayScreen({
    super.key,
    required this.appState,
    required this.onOpenSettings,
  });

  /// The app-wide state.
  final AppState appState;

  /// Opens the settings screen.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final facts = [
      for (final module in allModules) ...module.todayFacts(appState, now),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(greetingFor(now), style: textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              describeToday(now),
              style: textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.medium),
            _TileGrid(facts: facts),
          ],
        ),
      ),
    );
  }
}

/// Lays out the tiles two per row, with every tile in a row as tall as
/// the tallest.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.facts});

  final List<TodayFact> facts;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < facts.length; index += 2) {
      final hasSecond = index + 1 < facts.length;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : Spacing.small),
          // IntrinsicHeight gives both tiles the same height.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tileFor(facts[index])),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: hasSecond
                      ? _tileFor(facts[index + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _tileFor(TodayFact fact) {
    return InfoTile(
      icon: fact.icon,
      label: fact.label,
      value: fact.value,
      detail: fact.detail,
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
