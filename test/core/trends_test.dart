// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for [trendOf]: this week against the usual.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/dates.dart';
import 'package:ippo/core/trends.dart';

void main() {
  final day = DateTime(2026, 11, 20);

  /// A measure whose value is [valueFor] the number of days before [day].
  TrendMeasure measure(
    double? Function(int back) valueFor, {
    bool isPerWeek = false,
  }) {
    return TrendMeasure(
      label: 'Steps',
      valueOn: (date) => valueFor(day.difference(DateTime.parse(date)).inDays),
      format: (value) => value.toStringAsFixed(1),
      isPerWeek: isPerWeek,
    );
  }

  test('averages the 7 days before and the 4 weeks before those', () {
    // 9,000 a day in the 7 days before, 8,000 a day before those. The
    // day itself (back 0) is not over, so it does not count.
    final trend = trendOf(
      measure((back) => back == 0 ? 0 : (back <= 7 ? 9000 : 8000)),
      day,
    );

    expect(trend.recent, 9000);
    expect(trend.usual, 8000);
    expect(trend.direction, TrendDirection.up);
  });

  test('days without data are left out, not counted as zero', () {
    // Only every other day logged, at 7 h.
    final trend = trendOf(measure((back) => back.isEven ? 7 : null), day);

    expect(trend.recent, 7);
    expect(trend.usual, 7);
    expect(trend.direction, TrendDirection.steady);
  });

  test('within 5 % is steady; more is up or down', () {
    expect(
      trendOf(measure((back) => back <= 7 ? 104 : 100), day).direction,
      TrendDirection.steady,
    );
    expect(
      trendOf(measure((back) => back <= 7 ? 90 : 100), day).direction,
      TrendDirection.down,
    );
  });

  test('the usual needs at least 7 days of data', () {
    // The last 7 days, and only 6 days before them.
    final trend = trendOf(measure((back) => back <= 13 ? 5 : null), day);

    expect(trend.recent, 5);
    expect(trend.usual, isNull);
    expect(trend.direction, TrendDirection.unknown);
  });

  test('a per-week measure is a weekly total', () {
    // Workouts on 3 of the last 7 days; 2 a week before.
    final trend = trendOf(
      measure((back) {
        if (back <= 7) {
          return back <= 3 ? 1 : 0;
        }
        return back % 7 < 2 ? 1 : 0;
      }, isPerWeek: true),
      day,
    );

    expect(trend.recent, closeTo(3, 0.001));
    expect(trend.usual, closeTo(2, 0.001));
  });

  test('looks at exactly 7 + 28 days, not the day itself', () {
    final seen = <String>{};
    trendOf(
      TrendMeasure(
        label: 'x',
        valueOn: (date) {
          seen.add(date);
          return 1;
        },
        format: (value) => '$value',
      ),
      day,
    );
    expect(seen, hasLength(35));
    expect(seen, isNot(contains(formatDate(day))));
    expect(seen, contains(formatDate(addDays(day, -1))));
    expect(seen, contains(formatDate(addDays(day, -35))));
  });

  test('each measure can have its own steady band', () {
    // 1.2 % lower: steady at the default 5 %, down at 1 %.
    double? value(int back) => back <= 7 ? 67.4 : 68.2;
    expect(trendOf(measure(value), day).direction, TrendDirection.steady);
    expect(
      trendOf(
        TrendMeasure(
          label: 'Weight',
          valueOn: (date) => value(day.difference(DateTime.parse(date)).inDays),
          format: (value) => '$value',
          steadyWithin: 0.01,
        ),
        day,
      ).direction,
      TrendDirection.down,
    );
  });
}
