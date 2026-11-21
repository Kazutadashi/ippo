// SPDX-License-Identifier: GPL-3.0-or-later

/// The Charts screen: a short index of every measure over time, one card
/// per module, so the chart wanted is quick to find. A row opens its
/// chart on a screen of its own (see `chart_screen.dart`).
library;

import 'package:material_ui/material_ui.dart';

import '../../modules/all_modules.dart';
import '../app_state.dart';
import '../dates.dart';
import '../module.dart';
import '../widgets/section_card.dart';
import 'chart_card.dart';
import 'chart_math.dart';
import 'chart_screen.dart';
import 'chart_sparkline.dart';

/// How many days each row sums up: its small line and its trend.
const int _rowDays = 30;

/// One card per module with charts, in the order of `allModules`, and in
/// it one row per chart: its name, its change per week over the last 30
/// days, a small line of those days, and its latest 7-day mean.
class ChartsScreen extends StatelessWidget {
  /// Creates the screen for [appState].
  const ChartsScreen({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charts')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          // Modules without any chart yet are left out.
          final groups = [
            for (final module in allModules) (module, module.charts(appState)),
          ].where((group) => group.$2.isNotEmpty).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.screen,
              Spacing.small,
              Spacing.screen,
              24,
            ),
            children: [
              if (groups.isEmpty)
                const NoteText('Charts show here once something is logged.'),
              for (final (module, charts) in groups) ...[
                SectionCard(
                  children: [
                    CardHeader(
                      iconWidget: module.buildIcon(),
                      title: module.title,
                    ),
                    for (final spec in charts)
                      _ChartRow(
                        spec: spec,
                        onTap: () => _openChart(context, module, spec),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.small),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openChart(BuildContext context, IppoModule module, ChartSpec spec) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ChartScreen(appState: appState, module: module, title: spec.title),
      ),
    );
  }
}

/// One chart in the index: what it is, which way it went lately, and
/// where it is now. Tapping it opens the chart.
class _ChartRow extends StatelessWidget {
  const _ChartRow({required this.spec, required this.onTap});

  final ChartSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final last = today();
    final plot = chartPlotFor(
      spec,
      addDays(last, -(_rowDays - 1)),
      last,
      meanWindowFor(_rowDays),
    );
    final latestMean = plot == null
        ? null
        : [for (final piece in plot.mean) ...piece].lastOrNull;
    final change = plot == null
        ? null
        : summarize(plot.countedValues).changePerWeek;
    final unit = spec.unit;
    final summary = plot == null
        ? 'Nothing in the last $_rowDays days'
        : change == null
        ? 'Too few days for a trend'
        : '${formatSignedChange(spec, change)} per week';
    // A plain row rather than a ListTile, which keeps its height fixed:
    // with large text the row grows instead of cutting its numbers off.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.small),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit == null ? spec.title : '${spec.title} ($unit)',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (plot != null) ...[
                    const SizedBox(width: Spacing.small),
                    ChartSparkline(plot: plot),
                  ],
                  const SizedBox(width: Spacing.medium),
                  // The latest mean, labelled, so the number is never a
                  // guess. Both shrink a little rather than wrap.
                  SizedBox(
                    width: 76,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            latestMean == null
                                ? '–'
                                : spec.format(latestMean.value),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '7-day mean',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
