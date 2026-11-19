import 'package:engram/src/engine/difficulty_evaluation.dart';
import 'package:test/test.dart';

import '../helpers/quiz_item_helpers.dart';

void main() {
  group('evaluatePredictions', () {
    test('returns empty result for empty list', () {
      final result = evaluatePredictions([]);

      expect(result.evaluatedCount, 0);
      expect(result.totalPredicted, 0);
      expect(result.meanAbsoluteError, isNull);
      expect(result.bandAccuracy, isEmpty);
    });

    test('returns empty result when no cards have predictions', () {
      final items = [
        testQuizItem(id: 'q1', reviewCount: 10),
        testQuizItem(id: 'q2', reviewCount: 10),
      ];

      final result = evaluatePredictions(items);

      expect(result.evaluatedCount, 0);
      expect(result.totalPredicted, 0);
    });

    test('excludes cards below review threshold', () {
      final items = [
        testQuizItem(
          id: 'q1',
          predictedDifficulty: 5.0,
          difficulty: 5.0,
          reviewCount: 3, // below default threshold of 5
        ),
        testQuizItem(
          id: 'q2',
          predictedDifficulty: 7.0,
          difficulty: 7.0,
          reviewCount: 1,
        ),
      ];

      final result = evaluatePredictions(items);

      expect(result.evaluatedCount, 0);
      // totalPredicted counts all cards with predictions, regardless of reviews
      expect(result.totalPredicted, 2);
    });

    test('computes MAE for matching predictions', () {
      // Predictions exactly match FSRS actuals → MAE = 0
      final items = [
        testQuizItem(
          id: 'q1',
          predictedDifficulty: 5.0,
          difficulty: 5.0,
          reviewCount: 6,
        ),
        testQuizItem(
          id: 'q2',
          predictedDifficulty: 8.0,
          difficulty: 8.0,
          reviewCount: 10,
        ),
      ];

      final result = evaluatePredictions(items);

      expect(result.evaluatedCount, 2);
      expect(result.meanAbsoluteError, closeTo(0.0, 0.001));
    });

    test('computes MAE for mismatched predictions', () {
      // q1: |5.0 - 3.0| = 2.0
      // q2: |8.0 - 6.0| = 2.0
      // MAE = (2.0 + 2.0) / 2 = 2.0
      final items = [
        testQuizItem(
          id: 'q1',
          predictedDifficulty: 5.0,
          difficulty: 3.0,
          reviewCount: 5,
        ),
        testQuizItem(
          id: 'q2',
          predictedDifficulty: 8.0,
          difficulty: 6.0,
          reviewCount: 7,
        ),
      ];

      final result = evaluatePredictions(items);

      expect(result.evaluatedCount, 2);
      expect(result.meanAbsoluteError, closeTo(2.0, 0.001));
    });

    test('computes correct band accuracy', () {
      final items = [
        // Low band (1-3): predicted 2.0, actual 2.5 → correct (both low)
        testQuizItem(
          id: 'q1',
          predictedDifficulty: 2.0,
          difficulty: 2.5,
          reviewCount: 5,
        ),
        // Medium band (4-6): predicted 5.0, actual 5.5 → correct (both medium)
        testQuizItem(
          id: 'q2',
          predictedDifficulty: 5.0,
          difficulty: 5.5,
          reviewCount: 5,
        ),
        // High band (7-10): predicted 9.0, actual 4.0 → incorrect (high vs medium)
        testQuizItem(
          id: 'q3',
          predictedDifficulty: 9.0,
          difficulty: 4.0,
          reviewCount: 5,
        ),
      ];

      final result = evaluatePredictions(items);

      expect(result.evaluatedCount, 3);

      final low = result.bandAccuracy[DifficultyBand.low]!;
      expect(low.correct, 1);
      expect(low.predicted, 1);

      final medium = result.bandAccuracy[DifficultyBand.medium]!;
      expect(medium.correct, 1);
      expect(medium.predicted, 1);

      final high = result.bandAccuracy[DifficultyBand.high]!;
      expect(high.correct, 0);
      expect(high.predicted, 1);
    });

    test('skips items with null FSRS difficulty', () {
      final items = [
        testQuizItem(
          id: 'q1',
          predictedDifficulty: 5.0,
          difficulty: null,
          reviewCount: 10,
        ),
        testQuizItem(
          id: 'q2',
          predictedDifficulty: 5.0,
          difficulty: 5.0,
          reviewCount: 10,
        ),
      ];

      final result = evaluatePredictions(items);

      // q1 skipped (null difficulty), only q2 evaluated
      expect(result.evaluatedCount, 1);
      expect(result.totalPredicted, 2);
    });

    test('respects custom minReviews threshold', () {
      final items = [
        testQuizItem(
          id: 'q1',
          predictedDifficulty: 5.0,
          difficulty: 5.0,
          reviewCount: 3,
        ),
      ];

      // Default threshold (5) excludes this card
      expect(evaluatePredictions(items).evaluatedCount, 0);

      // Custom threshold (3) includes it
      expect(evaluatePredictions(items, minReviews: 3).evaluatedCount, 1);
    });
  });

  group('difficultyBand', () {
    test('low band for 1-3', () {
      expect(difficultyBand(1.0), DifficultyBand.low);
      expect(difficultyBand(2.5), DifficultyBand.low);
      expect(difficultyBand(3.0), DifficultyBand.low);
    });

    test('medium band for 4-6', () {
      expect(difficultyBand(3.1), DifficultyBand.medium);
      expect(difficultyBand(4.0), DifficultyBand.medium);
      expect(difficultyBand(5.0), DifficultyBand.medium);
      expect(difficultyBand(6.0), DifficultyBand.medium);
    });

    test('high band for 7-10', () {
      expect(difficultyBand(6.1), DifficultyBand.high);
      expect(difficultyBand(7.0), DifficultyBand.high);
      expect(difficultyBand(9.0), DifficultyBand.high);
      expect(difficultyBand(10.0), DifficultyBand.high);
    });
  });

  group('DifficultyEvaluationResult.empty', () {
    test('has zero counts and null MAE', () {
      final empty = DifficultyEvaluationResult.empty();
      expect(empty.evaluatedCount, 0);
      expect(empty.totalPredicted, 0);
      expect(empty.meanAbsoluteError, isNull);
      expect(empty.bandAccuracy, isEmpty);
    });
  });
}
