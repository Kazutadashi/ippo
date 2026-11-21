// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/core/charts/chart_data.dart';
import 'package:ippo/core/charts/chart_math.dart';

/// [value] on day [day] of November 2026.
DayValue onNovember(int day, double value) =>
    DayValue(DateTime(2026, 11, day), value);

void main() {
  group('runningMean', () {
    test('is the mean of the values in the window ending each day', () {
      final pieces = runningMean([
        onNovember(1, 10),
        onNovember(2, 20),
        onNovember(4, 30),
        onNovember(9, 40),
      ], 7);
      expect(pieces, hasLength(1));
      final means = [for (final value in pieces.single) value.value];
      // 9 Nov: the window is 3 to 9 Nov, holding 30 and 40.
      expect(means, [10, 15, 20, 35]);
    });

    test('stops across a gap as long as the window', () {
      final pieces = runningMean([
        onNovember(1, 10),
        onNovember(8, 20),
        onNovember(9, 30),
      ], 7);
      expect(pieces, hasLength(2));
      expect(pieces.last.map((value) => value.value), [20, 25]);
    });

    test('is empty without values', () {
      expect(runningMean(const [], 7), isEmpty);
    });
  });

  group('summarize', () {
    test('gives the mean, sample SD and least-squares slope per week', () {
      // A steady fall of 0.1 a day: −0.7 a week.
      final values = [
        for (var day = 1; day <= 15; day++) onNovember(day, 80 - day / 10),
      ];
      final summary = summarize(values);
      expect(summary.count, 15);
      expect(summary.mean, closeTo(79.2, 1e-9));
      expect(summary.standardDeviation, closeTo(0.4472, 1e-4));
      expect(summary.changePerWeek, closeTo(-0.7, 1e-9));
    });

    test('gives no change per week over less than a week', () {
      final summary = summarize([
        onNovember(1, 1),
        onNovember(2, 2),
        onNovember(3, 3),
      ]);
      expect(summary.changePerWeek, isNull);
      expect(summary.standardDeviation, 1);
    });

    test('gives no SD for one value, and nothing for none', () {
      expect(summarize([onNovember(1, 5)]).standardDeviation, isNull);
      expect(summarize(const []).mean, isNull);
    });
  });

  group('niceScale', () {
    test('rounds out to round numbers', () {
      final scale = niceScale(67.1, 68.5);
      expect(scale.step, 0.5);
      expect(scale.min, 67);
      expect(scale.max, 68.5);
      expect(scale.ticks, [67, 67.5, 68, 68.5]);
    });

    test('keeps fixed ends and the smallest step', () {
      expect(niceScale(20, 80, fixedMin: 0, fixedMax: 100).ticks, [
        0,
        25,
        50,
        75,
        100,
      ]);
      expect(niceScale(6, 8, smallestStep: 1).step, 1);
    });

    test('uses the steps given, such as hours', () {
      expect(niceScale(-1.5, 8.5, steps: [1, 2, 3, 6]).step, 3);
    });

    test('shows a little around a single value', () {
      final scale = niceScale(70, 70);
      expect(scale.min, lessThan(70));
      expect(scale.max, greaterThan(70));
    });
  });

  test('formatTickNumber writes axis labels', () {
    expect(formatTickNumber(1500, 500), '1,500');
    expect(formatTickNumber(10000, 5000), '10k');
    expect(formatTickNumber(0, 5000), '0');
    expect(formatTickNumber(67.5, 0.5), '67.5');
    expect(formatTickNumber(0.30000000000000004, 0.1), '0.3');
  });

  group('dateTicks', () {
    test('labels Mondays over a month', () {
      final ticks = dateTicks(DateTime(2026, 10, 23), DateTime(2026, 11, 21));
      expect(ticks.map((tick) => tick.label), [
        '26 Oct',
        '2 Nov',
        '9 Nov',
        '16 Nov',
      ]);
    });

    test('labels months, with the year for January', () {
      final ticks = dateTicks(DateTime(2026, 11, 1), DateTime(2027, 2, 15));
      expect(ticks.map((tick) => tick.label), ['Dec', '2027', 'Feb']);
    });

    test('labels years over a long span', () {
      final ticks = dateTicks(DateTime(2022, 6, 1), DateTime(2026, 11, 21));
      expect(ticks.map((tick) => tick.label), ['2023', '2024', '2025', '2026']);
    });
  });

  test('dailyValues leaves out days without a value', () {
    final values = dailyValues([
      '2026-11-02',
      '2026-11-01',
      'not a date',
      '2026-11-03',
      '2026-11-01',
    ], (date) => date == '2026-11-03' ? null : 1);
    expect(values.map((value) => value.date.day), [1, 2]);
  });
}
