import 'package:flutter_test/flutter_test.dart';

import 'package:engram/src/models/quiz_item.dart';

void main() {
  group('Phase 3 migration —', () {
    group('fromJson auto-migrates SM-2-only card', () {
      test('sets isFsrs to true with default difficulty 5.0', () {
        final json = {
          'id': 'q1',
          'conceptId': 'c1',
          'question': 'What is X?',
          'answer': 'X is Y',
          'easeFactor': 2.5,
          'interval': 6,
          'repetitions': 2,
          'nextReview': '2026-02-20T00:00:00.000Z',
          'lastReview': '2026-02-14T00:00:00.000Z',
          // No FSRS fields — pure SM-2 card
        };

        final item = QuizItem.fromJson(json);

        expect(item.isFsrs, isTrue);
        expect(item.difficulty, 5.0);
        expect(item.stability, isNotNull);
        expect(item.stability, greaterThan(0));
        expect(item.fsrsState, isNotNull);
        expect(item.lapses, isNotNull);
      });

      test('preserves existing nextReview and interval from SM-2', () {
        final json = {
          'id': 'q1',
          'conceptId': 'c1',
          'question': 'What is X?',
          'answer': 'X is Y',
          'easeFactor': 2.5,
          'interval': 6,
          'repetitions': 2,
          'nextReview': '2026-02-20T00:00:00.000Z',
          'lastReview': '2026-02-14T00:00:00.000Z',
        };

        final item = QuizItem.fromJson(json);

        expect(item.nextReview, DateTime.parse('2026-02-20T00:00:00.000Z'));
        expect(item.interval, 6);
        expect(item.lastReview, DateTime.parse('2026-02-14T00:00:00.000Z'));
      });
    });

    test('fromJson preserves existing FSRS card unchanged', () {
      final json = {
        'id': 'q2',
        'conceptId': 'c2',
        'question': 'What is Y?',
        'answer': 'Y is Z',
        'easeFactor': 2.5,
        'interval': 10,
        'repetitions': 3,
        'nextReview': '2026-02-25T00:00:00.000Z',
        'lastReview': '2026-02-15T00:00:00.000Z',
        'difficulty': 4.2,
        'stability': 12.5,
        'fsrsState': 2,
        'lapses': 1,
      };

      final item = QuizItem.fromJson(json);

      expect(item.difficulty, 4.2);
      expect(item.stability, 12.5);
      expect(item.fsrsState, 2);
      expect(item.lapses, 1);
    });

    test('fromJson migrates Phase 1 legacy card (difficulty only) to full FSRS',
        () {
      final json = {
        'id': 'q3',
        'conceptId': 'c3',
        'question': 'What is Z?',
        'answer': 'Z is W',
        'easeFactor': 2.5,
        'interval': 0,
        'repetitions': 0,
        'nextReview': '2026-02-20T00:00:00.000Z',
        'lastReview': null,
        'difficulty': 7.0,
        // No stability or fsrsState — Phase 1 legacy
      };

      final item = QuizItem.fromJson(json);

      expect(item.isFsrs, isTrue);
      expect(item.difficulty, 7.0); // preserved from Phase 1
      expect(item.stability, isNotNull);
      expect(item.stability, greaterThan(0));
      expect(item.fsrsState, isNotNull);
      expect(item.lapses, isNotNull);
    });

    test('newCard() without predictedDifficulty creates FSRS card with D=5.0',
        () {
      final item = QuizItem.newCard(
        id: 'q4',
        conceptId: 'c4',
        question: 'What is W?',
        answer: 'W is V',
      );

      expect(item.isFsrs, isTrue);
      expect(item.difficulty, 5.0);
      expect(item.stability, isNotNull);
      expect(item.stability, greaterThan(0));
      expect(item.fsrsState, isNotNull);
      expect(item.lapses, 0);
    });

    test('migrated card uses stability for isMasteredForUnlock', () {
      final json = {
        'id': 'q5',
        'conceptId': 'c5',
        'question': 'What is V?',
        'answer': 'V is U',
        'easeFactor': 2.5,
        'interval': 30, // SM-2 interval would qualify, but FSRS stability decides
        'repetitions': 5,
        'nextReview': '2026-03-20T00:00:00.000Z',
        'lastReview': '2026-02-15T00:00:00.000Z',
        // No FSRS fields — will be auto-migrated with low stability
      };

      final item = QuizItem.fromJson(json);

      // Auto-migrated card gets initial FSRS stability (~3.26 days),
      // which is below masteryUnlockDays (21).
      expect(item.isFsrs, isTrue);
      expect(item.isMasteredForUnlock, isFalse);
    });
  });
}
