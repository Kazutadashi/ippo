// SPDX-License-Identifier: GPL-3.0-or-later

/// How often a habit is meant to be done: "3 times every 7 days".
library;

/// How often a habit is meant to be done: [times] in every [perDays]
/// days. Every day is 1 in 1; every other day 1 in 2; three times a week
/// 3 in 7. Stored with the habit as `frequency` (see "Module: habits" in
/// `docs/data-format.md`).
///
/// A habit is *due* on a day until it has been done [times] times in the
/// [perDays] days ending that day. So "every 3 days", done on Monday, is
/// not due on Tuesday or Wednesday, and due again on Thursday. A day it is
/// not due is a waiting day: nothing to do, and it never counts as missed.
class HabitFrequency {
  /// Creates a frequency of [times] in [perDays] days.
  const HabitFrequency(this.times, this.perDays);

  /// Every day: the default, and what a habit without a valid frequency
  /// means.
  static const HabitFrequency everyDay = HabitFrequency(1, 1);

  /// The choices offered in the habit form, most common first.
  static const List<HabitFrequency> presets = [
    everyDay,
    HabitFrequency(1, 2),
    HabitFrequency(3, 7),
    HabitFrequency(2, 7),
    HabitFrequency(1, 7),
  ];

  /// How many times in each [perDays] days.
  final int times;

  /// How many days the [times] are spread over.
  final int perDays;

  /// Reads a frequency saved by [toJson]. Anything that is not a sensible
  /// frequency (missing, not whole numbers, more times than days) means
  /// every day, so an odd value never hides a habit.
  static HabitFrequency fromJson(Object? json) {
    if (json is! Map) {
      return everyDay;
    }
    final times = json['times'];
    final perDays = json['per_days'];
    if (times is! int || perDays is! int) {
      return everyDay;
    }
    if (times < 1 || perDays < 1 || times > perDays || perDays > 365) {
      return everyDay;
    }
    return HabitFrequency(times, perDays);
  }

  /// The frequency as it is stored: `{"times": 3, "per_days": 7}`.
  Map<String, Object?> toJson() => {'times': times, 'per_days': perDays};

  /// Whether the habit is meant for every day.
  bool get isEveryDay => times == perDays;

  /// Says how often, for people: "Every day", "Every other day", "Once a
  /// week", "3 times a week", "Every 3 days", "2 times every 10 days".
  String describe() {
    if (isEveryDay) {
      return 'Every day';
    }
    if (times == 1) {
      return switch (perDays) {
        2 => 'Every other day',
        7 => 'Once a week',
        _ => 'Every $perDays days',
      };
    }
    if (perDays == 7) {
      return times == 2 ? 'Twice a week' : '$times times a week';
    }
    return '$times times every $perDays days';
  }

  /// Whether a day not done (marked ✗, or not marked) is *covered*: the
  /// chain held around it, so it needed nothing. That is, every stretch of [perDays] days
  /// that includes the day has the habit done at least [times] times.
  ///
  /// "Every other day" (1 in 2), ✓ Monday, ✗ Tuesday, ✓ Wednesday:
  /// Monday–Tuesday and Tuesday–Wednesday each have a ✓, so Tuesday is
  /// covered. With ✗ on Wednesday too, Tuesday–Wednesday has none: the
  /// chain broke, and both stay ✗. A stretch that runs past today is
  /// not kept yet, so yesterday's ✗ waits for the next ✓. A daily
  /// habit's only stretch is the day itself, so it is never covered.
  ///
  /// [isDoneAt] tells whether the habit was done a number of days from
  /// the day: 0 is the day itself, -1 the day before, 1 the day after.
  /// Stretches starting before [firstOffset] (the habit's first marked
  /// day) are not checked: there was no chain to keep before it.
  bool coversDay(bool Function(int offset) isDoneAt, {int? firstOffset}) {
    final earliestStart = 1 - perDays;
    final firstStart = firstOffset == null || firstOffset < earliestStart
        ? earliestStart
        : firstOffset;
    if (firstStart > 0) {
      // The day is before the first mark: nothing to keep yet.
      return false;
    }
    // Each stretch that includes the day starts between [firstStart] and
    // the day itself. Count the first stretch, then slide it a day at a
    // time: add the day coming in, take away the day going out. (Asking
    // once per day keeps a long frequency, such as once a year, quick.)
    var done = 0;
    for (var offset = firstStart; offset < firstStart + perDays; offset++) {
      if (isDoneAt(offset)) {
        done++;
      }
    }
    for (var start = firstStart; start <= 0; start++) {
      if (done < times) {
        return false;
      }
      if (isDoneAt(start)) {
        done--;
      }
      if (isDoneAt(start + perDays)) {
        done++;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is HabitFrequency &&
      other.times == times &&
      other.perDays == perDays;

  @override
  int get hashCode => Object.hash(times, perDays);
}
