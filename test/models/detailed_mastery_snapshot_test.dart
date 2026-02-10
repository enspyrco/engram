import 'package:engram/src/models/detailed_mastery_snapshot.dart';
import 'package:engram/src/models/mastery_snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('DetailedMasterySnapshot', () {
    test('round-trip JSON serialization', () {
      const snapshot = DetailedMasterySnapshot(
        summary: MasterySnapshot(
          totalConcepts: 10,
          mastered: 5,
          learning: 3,
          newCount: 2,
          streak: 7,
        ),
        conceptMastery: {
          'c1': 'mastered',
          'c2': 'learning',
          'c3': 'mastered',
          'c4': 'due',
        },
        updatedAt: '2025-06-15T12:00:00.000Z',
      );

      final json = snapshot.toJson();
      final restored = DetailedMasterySnapshot.fromJson(json);

      expect(restored.summary.totalConcepts, 10);
      expect(restored.summary.mastered, 5);
      expect(restored.conceptMastery, hasLength(4));
      expect(restored.conceptMastery['c1'], 'mastered');
      expect(restored.updatedAt, '2025-06-15T12:00:00.000Z');
    });

    test('masteredConceptIds filters correctly', () {
      const snapshot = DetailedMasterySnapshot(
        summary: MasterySnapshot(),
        conceptMastery: {
          'c1': 'mastered',
          'c2': 'learning',
          'c3': 'mastered',
          'c4': 'due',
        },
      );

      expect(snapshot.masteredConceptIds, unorderedEquals(['c1', 'c3']));
    });

    test('learningConceptIds filters correctly', () {
      const snapshot = DetailedMasterySnapshot(
        summary: MasterySnapshot(),
        conceptMastery: {
          'c1': 'mastered',
          'c2': 'learning',
          'c3': 'learning',
        },
      );

      expect(snapshot.learningConceptIds, unorderedEquals(['c2', 'c3']));
    });

    test('fromJson handles missing fields gracefully', () {
      final snapshot = DetailedMasterySnapshot.fromJson(const {});

      expect(snapshot.summary.totalConcepts, 0);
      expect(snapshot.conceptMastery, isEmpty);
      expect(snapshot.updatedAt, isNull);
    });

    test('fromJson handles null conceptMastery', () {
      final snapshot = DetailedMasterySnapshot.fromJson(const {
        'summary': {'totalConcepts': 5, 'mastered': 2},
        'conceptMastery': null,
      });

      expect(snapshot.summary.totalConcepts, 5);
      expect(snapshot.conceptMastery, isEmpty);
    });
  });
}
