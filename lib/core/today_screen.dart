// SPDX-License-Identifier: GPL-3.0-or-later

/// The home tab: a quick glance at the day so far.
///
/// Like a weather app, it is information: a greeting, the date, and a
/// grid of tiles from every module. The bar at the bottom leads to each
/// module; the gear opens Settings and the chart button the charts.
library;

import 'package:material_ui/material_ui.dart';

import '../modules/all_modules.dart';
import 'app_state.dart';
import 'dates.dart';
import 'events/event_log.dart';
import 'module.dart';
import 'widgets/tab_app_bar.dart';
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
    required this.onOpenCharts,
    required this.onOpenModule,
  });

  /// The app-wide state.
  final AppState appState;

  /// Opens the settings screen.
  final VoidCallback onOpenSettings;

  /// Opens the charts screen, from the chart button and the Lately card.
  final VoidCallback onOpenCharts;

  /// Opens the tab of the module at this place in `allModules`, when its
  /// tile is tapped.
  final ValueChanged<int> onOpenModule;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

// FollowsToday redraws the tiles every minute, so "25 min ago" and
// "Awake for" stay current while the screen is open.
class _TodayScreenState extends State<TodayScreen> with FollowsToday {
  @override
  AppState get dayState => widget.appState;

  // The last of the seven days in the week grid, or null for today. It
  // stays put while the day shown is among the seven (tapping a day in
  // the grid moves only the highlight), and moves when it is not.
  DateTime? _gridEnd;

  /// Everything under the landscape, measured after each layout to
  /// work out [_landscapeGrowth].
  final GlobalKey _belowLandscape = GlobalKey();

  /// How much taller than [_landscapeHeight] the landscape is drawn: on
  /// a tall phone, the room the page would otherwise leave empty at the
  /// bottom (up to [_mostGrowth]), so Home ends at the tab bar.
  double _landscapeGrowth = 0;

  /// After a layout: makes the landscape fill what the page leaves empty
  /// of the [viewport] height. The page's height does not depend on the
  /// landscape's, so this settles after one more frame.
  void _fitLandscape(double viewport, double topInset, double landscapeHeight) {
    final below = _belowLandscape.currentContext?.findRenderObject();
    if (!mounted || below is! RenderBox || !below.hasSize) {
      return;
    }
    final free = viewport - topInset - landscapeHeight - below.size.height;
    final growth = free.clamp(0.0, _mostGrowth);
    if ((growth - _landscapeGrowth).abs() > 0.5) {
      setState(() => _landscapeGrowth = growth);
    }
  }

  /// The last day of the week grid for showing [day]: the grid's current
  /// seven days if [day] is one of them, else the seven ending on [day].
  DateTime _gridEndFor(DateTime day) {
    final end = _gridEnd ?? today();
    final isInGrid = !day.isAfter(end) && !day.isBefore(addDays(end, -6));
    final newEnd = isInGrid ? end : day;
    // Remembered without a redraw: it only changes along with the day,
    // which already redraws.
    _gridEnd = newEnd == today() ? null : newEnd;
    return newEnd;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final appState = widget.appState;
    final now = DateTime.now();
    final day = shownDay;
    // One tile per module, the same shape each, in a grid.
    final tiles = [
      for (final (index, module) in allModules.indexed)
        _tileFor(module, appState, day, now, () => widget.onOpenModule(index)),
    ];
    // The modules' rows of the week grid, for those that have any.
    final gridEnd = _gridEndFor(day);
    final weekRows = <WeekGridRow>[
      for (final module in allModules)
        for (final row in module.weekRows(appState, gridEnd))
          (title: module.title, icon: module.icon, row: row),
    ];
    final eventLog = appState.eventLog;
    final staleDevice = _staleDeviceNote(appState, now);
    final topInset = MediaQuery.paddingOf(context).top;
    // On a short screen (a phone on its side) a lower landscape, so the
    // tiles come into view.
    final landscapeHeight = _landscapeHeightFor(MediaQuery.sizeOf(context));
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Measured after this frame, to fit the landscape to the screen.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) =>
                _fitLandscape(constraints.maxHeight, topInset, landscapeHeight),
          );
          return RefreshIndicator(
            // Pull down to read the data folder again, for example after a
            // sync.
            onRefresh: appState.reloadEvents,
            child: ListView(
              // Pull to refresh works even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                // The landscape runs up behind the status bar, as scenery:
                // only the greeting and the gear sit on its sky. Everything
                // else is on the page, as on the tabs.
                Stack(
                  children: [
                    SkyHeader(
                      phase: SkyPhase.of(now),
                      height: topInset + landscapeHeight + _landscapeGrowth,
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
                              // On an earlier day, the heading says so.
                              showsToday ? greetingFor(now) : 'Looking back',
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
                  ],
                ),
                Column(
                  key: _belowLandscape,
                  children: [
                    // The date and the day bar, on the page as on every tab.
                    SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.only(right: Spacing.tight),
                        child: DayRow(day: day, onChanged: showDay),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                            WeekGrid(
                              end: gridEnd,
                              day: day,
                              rows: weekRows,
                              onDaySelected: showDay,
                              onOpenCharts: widget.onOpenCharts,
                            ),
                            const SizedBox(height: tileGap),
                          ],
                          _TileGrid(tiles: tiles),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// How tall the landscape is under the status bar: room for the greeting
/// on its sky, and the mountains below it.
const double _landscapeHeight = 112;

/// A screen shorter than this (a phone on its side) gets
/// [_shortLandscapeHeight].
const double _shortScreen = 500;

/// The landscape on a short screen: the greeting's sky and a low ridge.
const double _shortLandscapeHeight = 76;

/// The landscape's height on a screen of [size].
double _landscapeHeightFor(Size size) =>
    size.height < _shortScreen ? _shortLandscapeHeight : _landscapeHeight;

/// The most the landscape grows on a tall phone; past this, a page that
/// is still short leaves the rest empty rather than show a sky too big.
const double _mostGrowth = 160;

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

/// The tile of [module] for [day]; tapping it calls [onTap].
Widget _tileFor(
  IppoModule module,
  AppState appState,
  DateTime day,
  DateTime now,
  VoidCallback onTap,
) {
  final tile = module.homeTile(appState, day, now);
  return HomeTileCard(
    onTap: onTap,
    icon: module.buildIcon(),
    title: module.title,
    value: tile.value,
    valueNote: tile.valueNote,
    mark: tile.mark,
    note: tile.note,
    rows: tile.rows,
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
