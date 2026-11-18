// SPDX-License-Identifier: GPL-3.0-or-later

/// Measuring progress through a progression.
///
/// These numbers are worked out from the sets, never stored, so the
/// formula can improve without changing any data.
library;

import 'dart:math';

/// How far a day's sets are towards a step's target, from 0 to 1.
///
/// Takes the best [targetSets] sets of the day, counts each up to the
/// target (doing more than the target in one set does not make up for a
/// weak set), and divides by the full target. For a target of 3 × 12,
/// sets of 12, 10 and 8 give (12 + 10 + 8) / 36 = 0.83. Reaching the
/// target in every set gives exactly 1.
double stepProgress(
  List<int> setValues, {
  required int targetSets,
  required int targetPerSet,
}) {
  if (targetSets < 1 || targetPerSet < 1) {
    return 0;
  }
  final bestFirst = [...setValues]..sort((first, second) => second - first);
  var counted = 0;
  for (final value in bestFirst.take(targetSets)) {
    counted += min(value, targetPerSet);
  }
  return counted / (targetSets * targetPerSet);
}

/// Returns true if the sets reach the target, so the user can move up.
bool isTargetReached(
  List<int> setValues, {
  required int targetSets,
  required int targetPerSet,
}) {
  return stepProgress(
        setValues,
        targetSets: targetSets,
        targetPerSet: targetPerSet,
      ) >=
      1;
}

/// A single number for where someone is in a progression.
///
/// Step 1 covers levels 0 to 1, step 2 covers 1 to 2, and so on: the
/// level is the steps already passed plus the progress in the current
/// one. "Level 2.6" means step 3, 60% of the way to its target. Moving up
/// a step usually lowers the reps, but the level keeps rising, so a
/// chart of levels shows real progress.
double progressionLevel(int stepNumber, double progressInStep) {
  return (stepNumber - 1) + progressInStep.clamp(0, 1);
}
