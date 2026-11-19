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
import 'dates.dart';
import 'events/event_log.dart';
import 'widgets/follows_today.dart';
import 'widgets/info_tile.dart';
import 'widgets/section_card.dart';

/// The home tab.
class TodayScreen extends StatefulWidget {
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
  State<TodayScreen> createState() => _TodayScreenState();
}

// FollowsToday redraws the tiles every minute, so "25 min ago" and
// "Awake for" stay current while the screen is open.
class _TodayScreenState extends State<TodayScreen> with FollowsToday {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final appState = widget.appState;
    final now = DateTime.now();
    final tiles = [
      for (final module in allModules)
        for (final fact in module.todayFacts(appState, now))
          InfoTile(
            icon: module.icon,
            label: fact.label,
            value: fact.value,
            details: fact.details,
            note: fact.note,
          ),
    ];
    final eventLog = appState.eventLog;
    final staleDevice = _staleDeviceNote(appState, now);
    return Scaffold(
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: appState.reloadEvents,
        child: SafeArea(
          child: ListView(
            // Pull to refresh works even when the content is short.
            physics: const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      greetingFor(now),
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: widget.onOpenSettings,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                describeToday(today()),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              // Only for someone who has not logged anything yet: where
              // logging happens. It goes away by itself.
              if (eventLog != null && eventLog.events.isEmpty) ...[
                const SizedBox(height: Spacing.small),
                const NoteText(
                  'Log things in the tabs below. This page sums up your day.',
                ),
              ],
              // Only when another device has not been heard from in a
              // while, so missing entries are not a surprise.
              if (staleDevice != null) ...[
                const SizedBox(height: Spacing.small),
                NoteText(staleDevice),
              ],
              const SizedBox(height: Spacing.medium),
              _TileGrid(tiles: tiles),
            ],
          ),
        ),
      ),
    );
  }
}

/// How long another device can be quiet before Home mentions it.
const Duration _staleAfter = Duration(days: 1);

/// A note such as "my-desktop last synced 3 days ago", for the other
/// device heard from longest ago, if that is more than [_staleAfter].
/// Null when every other device is recent, or there are none.
String? _staleDeviceNote(AppState appState, DateTime now) {
  final eventLog = appState.eventLog;
  final ownId = appState.settings?.deviceId;
  if (eventLog == null || ownId == null) {
    return null;
  }
  DeviceLastSeen? oldest;
  for (final device in eventLog.lastSeenByDevice.values) {
    if (device.deviceId == ownId) {
      continue;
    }
    if (oldest == null ||
        device.latestRecordedAtUtc.isBefore(oldest.latestRecordedAtUtc)) {
      oldest = device;
    }
  }
  if (oldest == null) {
    return null;
  }
  final quiet = now.toUtc().difference(oldest.latestRecordedAtUtc);
  if (quiet < _staleAfter) {
    return null;
  }
  final days = quiet.inDays;
  return '${oldest.deviceName} last synced '
      '${days == 1 ? 'a day' : '$days days'} ago';
}

/// Lays out the tiles in rows, with every tile in a row as tall as the
/// tallest: two per row on a phone, more on a wide screen, and one per
/// row when the user has chosen large text.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    return LayoutBuilder(
      builder: (context, constraints) {
        // About 180 dp per tile, at least one and at most four.
        final perRow = largeText
            ? 1
            : (constraints.maxWidth / 180).floor().clamp(2, 4);
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += perRow) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : Spacing.small),
              // IntrinsicHeight gives every tile in the row one height.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < perRow; column++) ...[
                      if (column > 0) const SizedBox(width: Spacing.small),
                      Expanded(
                        child: start + column < tiles.length
                            ? tiles[start + column]
                            : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
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
