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
import 'dates.dart';
import 'events/event_log.dart';
import 'widgets/day_bar.dart';
import 'widgets/follows_today.dart';
import 'widgets/info_tile.dart';
import 'widgets/section_card.dart';
import 'widgets/sky_header.dart';
import 'widgets/week_grid.dart';

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
    final day = shownDay;
    // One tile per module, the same shape each, in a grid.
    final tiles = [
      for (final module in allModules) _tileFor(module, appState, day, now),
    ];
    // The modules' rows of the week grid, for those that have one.
    final weekRows = <WeekGridRow>[];
    for (final module in allModules) {
      final row = module.weekRow(appState, day);
      if (row != null) {
        weekRows.add((title: module.title, icon: module.icon, row: row));
      }
    }
    final eventLog = appState.eventLog;
    final staleDevice = _staleDeviceNote(appState, now);
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: RefreshIndicator(
        // Pull down to read the data folder again, for example after a
        // sync.
        onRefresh: appState.reloadEvents,
        child: ListView(
          // Pull to refresh works even when the content is short.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // The landscape runs up behind the status bar, with the
            // greeting and the gear on its sky, and the date with the day
            // bar on the ground at its foot.
            Stack(
              children: [
                SkyHeader(
                  phase: SkyPhase.of(now),
                  height: topInset + 156,
                  clearTop: topInset + 44,
                  // New mountains each day, the same all day long.
                  seed: SkyHeader.seedFor(today()),
                ),
                Positioned(
                  top: topInset + 2,
                  left: Spacing.screen,
                  right: Spacing.tight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          // On another day, the heading says which way.
                          showsToday
                              ? greetingFor(now)
                              : day.isAfter(today())
                              ? 'Looking ahead'
                              : 'Looking back',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: _onLandscape,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        color: Colors.white,
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: widget.onOpenSettings,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: Spacing.screen,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          describeToday(day),
                          style: textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            shadows: _onLandscape,
                          ),
                        ),
                      ),
                      // White on the landscape, like the greeting, in
                      // light mode too: the ground there is always dark
                      // enough. A day other than today gets a see-through
                      // white pill.
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: colors.copyWith(
                            onSurface: Colors.white,
                            onSurfaceVariant: Colors.white,
                            secondaryContainer: Colors.white24,
                          ),
                        ),
                        child: DayBar(day: day, onChanged: showDay),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Only for someone who has not logged anything yet:
                  // where logging happens. It goes away by itself.
                  if (eventLog != null && eventLog.events.isEmpty) ...[
                    const SizedBox(height: Spacing.small),
                    const NoteText(
                      'Log things in the tabs below. This page sums up your '
                      'day.',
                    ),
                  ],
                  // Only when another device has not been heard from in a
                  // while, so missing entries are not a surprise.
                  if (staleDevice != null) ...[
                    const SizedBox(height: Spacing.small),
                    NoteText(staleDevice),
                  ],
                  // Room between a note above and the tiles.
                  if (staleDevice != null ||
                      (eventLog != null && eventLog.events.isEmpty))
                    const SizedBox(height: tileGap),
                  // The week first, the wider view; then today, module by
                  // module.
                  if (weekRows.isNotEmpty) ...[
                    WeekGrid(day: day, rows: weekRows),
                    const SizedBox(height: tileGap),
                  ],
                  _TileGrid(tiles: tiles),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft shadow under white text on the landscape, so it stays
/// readable on light snow or a pale sky.
const List<Shadow> _onLandscape = [
  Shadow(color: Colors.black38, blurRadius: 6),
];

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

/// The tile of [module] for [day].
Widget _tileFor(
  IppoModule module,
  AppState appState,
  DateTime day,
  DateTime now,
) {
  final tile = module.homeTile(appState, day, now);
  return HomeTileCard(
    icon: module.icon,
    title: module.title,
    value: tile.value,
    valueNote: tile.valueNote,
    mark: tile.mark,
    lines: tile.lines,
  );
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
        // About 180 dp per tile, at least two and at most four.
        final perRow = largeText
            ? 1
            : (constraints.maxWidth / 180).floor().clamp(2, 4);
        return Column(
          children: [
            for (var start = 0; start < tiles.length; start += perRow)
              Padding(
                padding: EdgeInsets.only(top: start == 0 ? 0 : tileGap),
                child: _row(tiles.skip(start).take(perRow).toList(), perRow),
              ),
          ],
        );
      },
    );
  }

  /// One row of [columns] equal places; empty places stay empty.
  Widget _row(List<Widget> row, int columns) {
    // IntrinsicHeight gives every tile in the row one height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: tileGap),
            Expanded(
              child: column < row.length ? row[column] : const SizedBox(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Writes a day for the heading, for example `Tuesday, 18 Nov`. The
/// month is short, so the date fits on one line beside the day bar.
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';
}

/// A greeting for the time of day: `Good morning` from 05:00 (when a
/// new day starts, see `dayStartHour`), `Good afternoon` from noon and
/// `Good evening` from 18:00 until the day ends in the small hours.
String greetingFor(DateTime moment) {
  final hour = moment.hour;
  if (hour >= dayStartHour && hour < 12) {
    return 'Good morning';
  }
  if (hour >= 12 && hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}
