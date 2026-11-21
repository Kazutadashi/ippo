// SPDX-License-Identifier: GPL-3.0-or-later

/// One chart on a screen of its own, opened from a row of the Charts
/// screen: a larger plot, with the days shown chosen freely.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../dates.dart';
import '../module.dart';
import '../widgets/section_card.dart';
import 'chart_card.dart';

/// The usual periods, each ending today.
enum ChartPeriod {
  /// The last 7 days.
  week('Week', 7),

  /// The last 30 days.
  month('Month', 30),

  /// The last 13 weeks.
  quarter('3 mo', 91),

  /// The last 365 days.
  year('Year', 365),

  /// Everything ever logged.
  all('All', null);

  const ChartPeriod(this.label, this.days);

  /// Its name on the period switch.
  final String label;

  /// How many days it covers, ending today; null for all of them.
  final int? days;
}

/// How tall the plot is on this screen, where it has the room.
const double _plotHeight = 240;

/// The chart called [title] of [module], over a period chosen at the top:
/// one of the usual periods, or any days picked on a calendar, and ‹ ›
/// to step back and forward by the same number of days.
///
/// The chart is looked up again whenever the data changes, so new
/// entries show at once.
class ChartScreen extends StatefulWidget {
  /// Creates the screen.
  const ChartScreen({
    super.key,
    required this.appState,
    required this.module,
    required this.title,
  });

  /// The app-wide state.
  final AppState appState;

  /// The module the chart belongs to.
  final IppoModule module;

  /// The chart's title, which finds it among the module's charts.
  final String title;

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  /// The period chosen, or null when [_customDays] are shown instead.
  ChartPeriod? _period = ChartPeriod.quarter;

  /// Days picked on the calendar or reached with ‹ ›.
  DateTimeRange? _customDays;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final spec = widget.module
              .charts(widget.appState)
              .where((chart) => chart.title == widget.title)
              .firstOrNull;
          if (spec == null) {
            return const Padding(
              padding: EdgeInsets.all(Spacing.screen),
              child: NoteText('Nothing is logged for this chart any more.'),
            );
          }
          final days = _daysShown(spec);
          final isToday = days.end == today();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.screen,
              Spacing.small,
              Spacing.screen,
              24,
            ),
            children: [
              SegmentedButton<ChartPeriod>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                // Picked days are none of the usual periods.
                emptySelectionAllowed: true,
                segments: [
                  for (final period in ChartPeriod.values)
                    ButtonSegment(value: period, label: Text(period.label)),
                ],
                selected: _period == null ? const {} : {_period!},
                onSelectionChanged: (chosen) {
                  if (chosen.isEmpty) {
                    return;
                  }
                  setState(() {
                    _period = chosen.first;
                    _customDays = null;
                  });
                },
              ),
              const SizedBox(height: Spacing.small),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Earlier',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _show(_stepped(days, back: true)),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(describeDays(days.start, days.end)),
                      onPressed: () => _pickDays(days),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Later',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: isToday
                        ? null
                        : () => _show(_stepped(days, back: false)),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.small),
              ChartCard(
                spec: spec,
                icon: widget.module.buildIcon(),
                first: days.start,
                last: days.end,
                plotHeight: _plotHeight,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows [days] instead of a usual period.
  void _show(DateTimeRange days) {
    setState(() {
      _period = null;
      _customDays = days;
    });
  }

  /// Lets the user pick the first and last day on a calendar.
  Future<void> _pickDays(DateTimeRange shown) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today(),
      initialDateRange: shown,
      helpText: 'Days to show',
    );
    if (picked != null) {
      _show(picked);
    }
  }

  /// The days shown: those picked, or the period chosen.
  ///
  /// A period reaching back before anything was logged starts at the
  /// first day logged instead (at least a week before today), so a new
  /// chart is not mostly empty.
  DateTimeRange _daysShown(ChartSpec spec) {
    final custom = _customDays;
    if (custom != null) {
      return custom;
    }
    final last = today();
    final days = _period?.days;
    var first = spec.firstDate ?? last;
    if (days != null && addDays(last, -(days - 1)).isAfter(first)) {
      first = addDays(last, -(days - 1));
    }
    final latestStart = addDays(last, -6);
    return DateTimeRange(
      start: first.isAfter(latestStart) ? latestStart : first,
      end: last,
    );
  }
}

/// The same number of days as [days], just before them ([back]) or just
/// after them, never past today.
DateTimeRange _stepped(DateTimeRange days, {required bool back}) {
  final length = daysBetween(days.start, days.end) + 1;
  if (back) {
    return DateTimeRange(
      start: addDays(days.start, -length),
      end: addDays(days.end, -length),
    );
  }
  final last = today();
  var end = addDays(days.end, length);
  if (end.isAfter(last)) {
    end = last;
  }
  return DateTimeRange(start: addDays(end, -(length - 1)), end: end);
}

/// Days from [first] to [last] in a few words: `26 Oct – 21 Nov 2026`,
/// with both years when they differ: `1 Dec 2025 – 31 Jan 2026`.
String describeDays(DateTime first, DateTime last) {
  String dayAndMonth(DateTime day) => '${day.day} ${shortMonthName(day.month)}';
  if (first.year == last.year) {
    return '${dayAndMonth(first)} – ${dayAndMonth(last)} ${last.year}';
  }
  return '${dayAndMonth(first)} ${first.year} – '
      '${dayAndMonth(last)} ${last.year}';
}
