import 'package:engram/src/models/quiz_item.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2025, 6, 15);

  group('isFsrs', () {
    test('true when difficulty, stability, and fsrsState are all set', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 0,
        nextReview: now,
        lastReview: null,
        difficulty: 5.0,
        stability: 3.26,
        fsrsState: 1,
        lapses: 0,
      );
      expect(item.isFsrs, isTrue);
    });

    test('false when stability is null (Phase 1 legacy card)', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 0,
        nextReview: now,
        lastReview: null,
        difficulty: 5.0,
      );
      expect(item.isFsrs, isFalse);
    });

    test('false when all FSRS fields are null (pure SM-2 card)', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 0,
        nextReview: now,
        lastReview: null,
      );
      expect(item.isFsrs, isFalse);
    });

    test('false when fsrsState is null', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 0,
        nextReview: now,
        lastReview: null,
        difficulty: 5.0,
        stability: 3.26,
      );
      expect(item.isFsrs, isFalse);
    });
  });

  group('isMasteredForUnlock', () {
    test('FSRS card: true when stability >= 21', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 5,
        nextReview: now,
        lastReview: null,
        difficulty: 5.0,
        stability: 21.0,
        fsrsState: 2,
        lapses: 0,
      );
      expect(item.isMasteredForUnlock, isTrue);
    });

    test('FSRS card: false when stability < 21', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 25,
        nextReview: now,
        lastReview: null,
        difficulty: 5.0,
        stability: 15.0,
        fsrsState: 2,
        lapses: 0,
      );
      expect(item.isMasteredForUnlock, isFalse);
    });

    test('false when stability is null', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 25,
        nextReview: now,
        lastReview: null,
      );
      expect(item.isMasteredForUnlock, isFalse);
    });
  });

  group('newCard', () {
    test('without predictedDifficulty creates FSRS card with D=5.0', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        now: now,
      );

      expect(item.isFsrs, isTrue);
      expect(item.difficulty, 5.0);
      expect(item.stability, isNotNull);
      expect(item.stability!, greaterThan(0));
      expect(item.fsrsState, 1); // learning
      expect(item.lapses, 0);
      expect(item.interval, 0);
    });

    test('with predictedDifficulty bootstraps full FSRS state', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        predictedDifficulty: 7.0,
        now: now,
      );

      expect(item.isFsrs, isTrue);
      expect(item.difficulty, closeTo(7.0, 0.01));
      expect(item.stability, isNotNull);
      expect(item.stability!, greaterThan(0));
      expect(item.fsrsState, 1); // learning
      expect(item.lapses, 0);
    });

    test('predictedDifficulty is clamped to 1.0-10.0', () {
      final tooLow = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        predictedDifficulty: -5.0,
        now: now,
      );
      expect(tooLow.difficulty, closeTo(1.0, 0.01));

      final tooHigh = QuizItem.newCard(
        id: 'q2',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        predictedDifficulty: 15.0,
        now: now,
      );
      expect(tooHigh.difficulty, closeTo(10.0, 0.01));
    });
  });

  group('fromJson / toJson round-trip', () {
    test('legacy SM-2 card auto-migrates to FSRS on fromJson', () {
      final original = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 6,
        nextReview: now,
        lastReview: now.subtract(const Duration(days: 6)),
      );

      final restored = QuizItem.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.interval, original.interval);
      // Auto-migrated to FSRS
      expect(restored.isFsrs, isTrue);
      expect(restored.difficulty, 5.0); // default
      expect(restored.stability, isNotNull);
      expect(restored.fsrsState, isNotNull);
      expect(restored.lapses, isNotNull);
      // Preserves scheduling state
      expect(restored.nextReview, original.nextReview);
      expect(restored.lastReview, original.lastReview);
    });

    test('FSRS card round-trips correctly', () {
      final original = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'Q?',
        answer: 'A.',
        interval: 3,
        nextReview: now,
        lastReview: now.subtract(const Duration(days: 3)),
        difficulty: 5.0,
        stability: 3.26,
        fsrsState: 2,
        lapses: 1,
      );

      final restored = QuizItem.fromJson(original.toJson());
      expect(restored.difficulty, original.difficulty);
      expect(restored.stability, original.stability);
      expect(restored.fsrsState, original.fsrsState);
      expect(restored.lapses, original.lapses);
      expect(restored.isFsrs, isTrue);
    });
  });
}
