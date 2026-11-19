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
import 'theme.dart';
import 'widgets/day_bar.dart';
import 'widgets/follows_today.dart';
import 'widgets/info_tile.dart';
import 'widgets/section_card.dart';
import 'widgets/sky_header.dart';

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
    final tiles = <_Tile>[
      // The week first: the wider view, before the details of the day.
      _weekTile(appState, day),
      for (final module in allModules)
        for (final fact in module.dayFacts(appState, day, now))
          _Tile(
            InfoTile(
              icon: module.icon,
              color: moduleTone(module.color, Theme.of(context).brightness),
              label: fact.label,
              value: fact.value,
              valueNote: fact.valueNote,
              details: fact.details,
              note: fact.note,
              visual: fact.visual,
              isWide: fact.isWide,
            ),
            isWide: fact.isWide,
          ),
    ];
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
                  height: topInset + 116,
                  clearTop: topInset + 44,
                ),
                Positioned(
                  top: topInset + 2,
                  left: Spacing.screen,
                  right: Spacing.tight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          // Looking back at another day, the heading
                          // says so.
                          showsToday ? greetingFor(now) : 'Looking back',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black38, blurRadius: 6),
                            ],
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
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      DayBar(day: day, onChanged: showDay),
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

/// A tile for the grid, and whether it takes a whole row.
class _Tile {
  const _Tile(this.tile, {this.isWide = false});

  final Widget tile;
  final bool isWide;
}

/// The "Last 7 days" tile, one slim row: the week's days as dots (from
/// the first module that draws them, the habits) on the left, and one
/// number from each module on the right, such as sleep per night. A
/// summary, not a chart: the trends belong in an analysis of the data.
_Tile _weekTile(AppState appState, DateTime day) {
  final summaries = [
    for (final module in allModules)
      if (module.weekSummary(appState, day) case final summary?) summary,
  ];
  Widget? strip;
  for (final module in allModules) {
    strip ??= module.weekStrip(appState, day);
  }
  final hasNothing = summaries.isEmpty && strip == null;
  return _Tile(
    InfoTile(
      icon: Icons.date_range,
      label: 'Last 7 days',
      value: '',
      note: hasNothing ? 'Nothing logged in these days.' : null,
      visual: hasNothing
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (strip != null) Expanded(flex: 5, child: strip),
                if (strip != null && summaries.isNotEmpty)
                  const SizedBox(width: Spacing.medium),
                if (summaries.isNotEmpty)
                  Expanded(flex: 6, child: LabelledValues(details: summaries)),
              ],
            ),
      isWide: true,
    ),
    isWide: true,
  );
}

/// Lays out the tiles in rows, with every tile in a row as tall as the
/// tallest: two per row on a phone, more on a wide screen, and one per
/// row when the user has chosen large text. A wide tile has a row of
/// its own.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    return LayoutBuilder(
      builder: (context, constraints) {
        // About 180 dp per tile, at least one and at most four.
        final perRow = largeText
            ? 1
            : (constraints.maxWidth / 180).floor().clamp(2, 4);
        // Group the tiles into rows: a wide tile alone, the others
        // filling rows of perRow.
        final rows = <List<_Tile>>[];
        for (final tile in tiles) {
          final last = rows.isEmpty ? null : rows.last;
          final fits =
              last != null &&
              !tile.isWide &&
              !last.first.isWide &&
              last.length < perRow;
          if (fits) {
            last.add(tile);
          } else {
            rows.add([tile]);
          }
        }
        return Column(
          children: [
            for (var index = 0; index < rows.length; index++)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : Spacing.small),
                child: _row(rows[index], rows[index].first.isWide ? 1 : perRow),
              ),
          ],
        );
      },
    );
  }

  /// One row of [columns] equal places; empty places stay empty.
  Widget _row(List<_Tile> row, int columns) {
    // IntrinsicHeight gives every tile in the row one height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: Spacing.small),
            Expanded(
              child: column < row.length ? row[column].tile : const SizedBox(),
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
