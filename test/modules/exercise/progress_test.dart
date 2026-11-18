// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for the progress and level formulas.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ippo/modules/exercise/progress.dart';

void main() {
  group('stepProgress', () {
    test('the example from the documentation: 12, 10, 8 of 3 × 12', () {
      final progress = stepProgress(
        [12, 10, 8],
        targetSets: 3,
        targetPerSet: 12,
      );
      expect(progress, closeTo(30 / 36, 1e-9));
    });

    test('reaching the target in every set is exactly 1', () {
      expect(stepProgress([12, 12, 12], targetSets: 3, targetPerSet: 12), 1);
    });

    test('one huge set does not make up for missing sets', () {
      expect(
        stepProgress([50], targetSets: 3, targetPerSet: 12),
        closeTo(1 / 3, 1e-9),
      );
    });

    test('only the best sets count, so extra weak sets do not hurt', () {
      expect(
        stepProgress([3, 12, 2, 12, 12], targetSets: 3, targetPerSet: 12),
        1,
      );
    });

    test('no sets, or a broken target, is 0', () {
      expect(stepProgress([], targetSets: 3, targetPerSet: 12), 0);
      expect(stepProgress([10], targetSets: 0, targetPerSet: 12), 0);
      expect(stepProgress([10], targetSets: 3, targetPerSet: 0), 0);
    });
  });

  test('isTargetReached', () {
    expect(
      isTargetReached([12, 12, 12], targetSets: 3, targetPerSet: 12),
      isTrue,
    );
    expect(
      isTargetReached([12, 12, 11], targetSets: 3, targetPerSet: 12),
      isFalse,
    );
  });

  group('progressionLevel', () {
    test('step 3, 60% of the way, is level 2.6', () {
      expect(progressionLevel(3, 0.6), closeTo(2.6, 1e-9));
    });

    test('moving up keeps the level rising', () {
      // Mastering step 2 is level 2; just starting step 3 is also 2,
      // and any progress in step 3 is above it.
      expect(progressionLevel(2, 1), 2);
      expect(progressionLevel(3, 0), 2);
      expect(progressionLevel(3, 0.1), greaterThan(2));
    });

    test('progress is kept between 0 and 1', () {
      expect(progressionLevel(1, 1.5), 1);
      expect(progressionLevel(2, -1), 1);
    });
  });
}
