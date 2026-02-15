import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:test/test.dart';

void main() {
  final baseTime = DateTime.utc(2026, 2, 15, 12);

  group('reviewFsrs', () {
    // Start with a card initialized from Claude's prediction
    late FsrsResult initialState;

    setUp(() {
      initialState = initializeFsrsCard(
        predictedDifficulty: 5.0,
        now: baseTime,
      );
    });

    test('rating good increases stability', () {
      final result = reviewFsrs(
        rating: FsrsRating.good,
        difficulty: initialState.difficulty,
        stability: initialState.stability,
        fsrsState: initialState.fsrsState,
        lapses: initialState.lapses,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 1)),
      );

      expect(result.stability, greaterThan(initialState.stability));
      expect(result.intervalDays, greaterThan(0));
    });

    test('rating easy produces higher stability than good', () {
      final reviewTime = baseTime.add(const Duration(days: 1));

      final goodResult = reviewFsrs(
        rating: FsrsRating.good,
        difficulty: initialState.difficulty,
        stability: initialState.stability,
        fsrsState: initialState.fsrsState,
        lapses: initialState.lapses,
        lastReview: baseTime,
        now: reviewTime,
      );

      final easyResult = reviewFsrs(
        rating: FsrsRating.easy,
        difficulty: initialState.difficulty,
        stability: initialState.stability,
        fsrsState: initialState.fsrsState,
        lapses: initialState.lapses,
        lastReview: baseTime,
        now: reviewTime,
      );

      expect(easyResult.stability, greaterThan(goodResult.stability));
    });

    test('rating again decreases stability', () {
      // First graduate the card to review state with a good review
      final afterGood = reviewFsrs(
        rating: FsrsRating.good,
        difficulty: initialState.difficulty,
        stability: initialState.stability,
        fsrsState: initialState.fsrsState,
        lapses: initialState.lapses,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 1)),
      );

      // Now review with "again" — stability should drop
      final afterAgain = reviewFsrs(
        rating: FsrsRating.again,
        difficulty: afterGood.difficulty,
        stability: afterGood.stability,
        fsrsState: afterGood.fsrsState,
        lapses: afterGood.lapses,
        lastReview: baseTime.add(const Duration(days: 1)),
        now: baseTime.add(const Duration(days: 2)),
      );

      expect(afterAgain.stability, lessThan(afterGood.stability));
    });

    test('each rating produces valid FSRS state', () {
      for (final rating in FsrsRating.values) {
        final result = reviewFsrs(
          rating: rating,
          difficulty: initialState.difficulty,
          stability: initialState.stability,
          fsrsState: initialState.fsrsState,
          lapses: initialState.lapses,
          lastReview: baseTime,
          now: baseTime.add(const Duration(days: 1)),
        );

        expect(result.difficulty, inInclusiveRange(1.0, 10.0));
        expect(result.stability, greaterThan(0));
        expect(result.fsrsState, anyOf(1, 2, 3));
        expect(result.lapses, greaterThanOrEqualTo(0));
        expect(result.nextReview, isNotNull);
      }
    });

    test('lapses increment on again while in review state', () {
      // Set up a card in review state (fsrsState = 2)
      final result = reviewFsrs(
        rating: FsrsRating.again,
        difficulty: 5.0,
        stability: 10.0,
        fsrsState: 2, // review
        lapses: 3,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 10)),
      );

      expect(result.lapses, 4);
    });

    test('lapses do not increment on again while in learning state', () {
      final result = reviewFsrs(
        rating: FsrsRating.again,
        difficulty: 5.0,
        stability: 3.0,
        fsrsState: 1, // learning
        lapses: 0,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 1)),
      );

      expect(result.lapses, 0);
    });

    test('desiredRetention affects interval length', () {
      final highRetention = reviewFsrs(
        rating: FsrsRating.good,
        difficulty: 5.0,
        stability: 10.0,
        fsrsState: 2,
        lapses: 0,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 10)),
        desiredRetention: 0.95,
      );

      final lowRetention = reviewFsrs(
        rating: FsrsRating.good,
        difficulty: 5.0,
        stability: 10.0,
        fsrsState: 2,
        lapses: 0,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 10)),
        desiredRetention: 0.80,
      );

      // Higher retention target → shorter intervals (review more often)
      expect(highRetention.intervalDays, lessThan(lowRetention.intervalDays));
    });
  });

  group('initializeFsrsCard', () {
    test('sets difficulty from prediction', () {
      final result = initializeFsrsCard(
        predictedDifficulty: 7.5,
        now: baseTime,
      );

      expect(result.difficulty, 7.5);
      expect(result.fsrsState, 1); // learning
      expect(result.lapses, 0);
      expect(result.intervalDays, 0);
      expect(result.nextReview, baseTime);
    });

    test('clamps difficulty to 1-10 range', () {
      final tooLow = initializeFsrsCard(
        predictedDifficulty: 0.5,
        now: baseTime,
      );
      expect(tooLow.difficulty, 1.0);

      final tooHigh = initializeFsrsCard(
        predictedDifficulty: 15.0,
        now: baseTime,
      );
      expect(tooHigh.difficulty, 10.0);
    });

    test('defaults to midpoint difficulty without prediction', () {
      final result = initializeFsrsCard(now: baseTime);
      expect(result.difficulty, 5.0);
    });

    test('sets initial stability from FSRS parameters', () {
      final result = initializeFsrsCard(now: baseTime);
      expect(result.stability, greaterThan(0));
    });
  });

  group('fsrsRetrievability', () {
    test('is high immediately after review', () {
      final r = fsrsRetrievability(
        stability: 10.0,
        fsrsState: 2,
        lastReview: baseTime,
        now: baseTime,
      );

      expect(r, closeTo(1.0, 0.01));
    });

    test('decreases over time', () {
      final r1 = fsrsRetrievability(
        stability: 10.0,
        fsrsState: 2,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 5)),
      );

      final r2 = fsrsRetrievability(
        stability: 10.0,
        fsrsState: 2,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 20)),
      );

      expect(r1, greaterThan(r2));
      expect(r1, lessThan(1.0));
      expect(r2, greaterThan(0.0));
    });

    test('returns 0 for zero stability', () {
      final r = fsrsRetrievability(
        stability: 0.0,
        fsrsState: 2,
        lastReview: baseTime,
        now: baseTime.add(const Duration(days: 1)),
      );

      expect(r, 0.0);
    });

    test('higher stability decays slower', () {
      final reviewTime = baseTime.add(const Duration(days: 10));

      final lowStability = fsrsRetrievability(
        stability: 5.0,
        fsrsState: 2,
        lastReview: baseTime,
        now: reviewTime,
      );

      final highStability = fsrsRetrievability(
        stability: 30.0,
        fsrsState: 2,
        lastReview: baseTime,
        now: reviewTime,
      );

      expect(highStability, greaterThan(lowStability));
    });
  });

  group('mean reversion', () {
    test('difficulty moves toward midpoint over repeated reviews', () {
      // Start with high difficulty
      var difficulty = 9.0;
      var stability = 3.0;
      var fsrsState = 1;
      var lapses = 0;
      var lastReview = baseTime;

      // Repeatedly rate "good" — difficulty should decrease toward midpoint
      for (var i = 0; i < 10; i++) {
        final reviewTime = lastReview.add(const Duration(days: 1));
        final result = reviewFsrs(
          rating: FsrsRating.good,
          difficulty: difficulty,
          stability: stability,
          fsrsState: fsrsState,
          lapses: lapses,
          lastReview: lastReview,
          now: reviewTime,
        );

        difficulty = result.difficulty;
        stability = result.stability;
        fsrsState = result.fsrsState;
        lapses = result.lapses;
        lastReview = reviewTime;
      }

      // After 10 "good" reviews, difficulty should have decreased from 9.0
      expect(difficulty, lessThan(9.0));
    });
  });
}
