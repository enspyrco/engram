import 'package:engram/src/engine/mastery_state.dart';
import 'package:engram/src/models/detailed_mastery_snapshot.dart';
import 'package:engram/src/models/mastery_snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('DetailedMasterySnapshot', () {
    test('round-trip JSON serialization', () {
      final snapshot = DetailedMasterySnapshot(
        summary: const MasterySnapshot(
          totalConcepts: 10,
          mastered: 5,
          learning: 3,
          newCount: 2,
          streak: 7,
        ),
        conceptMastery: const {
          'c1': MasteryState.mastered,
          'c2': MasteryState.learning,
          'c3': MasteryState.mastered,
          'c4': MasteryState.due,
        },
        updatedAt: DateTime.utc(2025, 6, 15, 12),
      );

      final json = snapshot.toJson();
      final restored = DetailedMasterySnapshot.fromJson(json);

      expect(restored.summary.totalConcepts, 10);
      expect(restored.summary.mastered, 5);
      expect(restored.conceptMastery, hasLength(4));
      expect(restored.conceptMastery['c1'], MasteryState.mastered);
      expect(restored.updatedAt, DateTime.utc(2025, 6, 15, 12));
    });

    test('masteredConceptIds filters correctly', () {
      const snapshot = DetailedMasterySnapshot(
        summary: MasterySnapshot(),
        conceptMastery: {
          'c1': MasteryState.mastered,
          'c2': MasteryState.learning,
          'c3': MasteryState.mastered,
          'c4': MasteryState.due,
        },
      );

      expect(snapshot.masteredConceptIds, unorderedEquals(['c1', 'c3']));
    });

    test('learningConceptIds filters correctly', () {
      const snapshot = DetailedMasterySnapshot(
        summary: MasterySnapshot(),
        conceptMastery: {
          'c1': MasteryState.mastered,
          'c2': MasteryState.learning,
          'c3': MasteryState.learning,
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

    test('fromJson drops unknown mastery state names', () {
      final snapshot = DetailedMasterySnapshot.fromJson(const {
        'conceptMastery': {'c1': 'mastered', 'c2': 'transcendent', 'c3': 7},
      });

      expect(snapshot.conceptMastery, {'c1': MasteryState.mastered});
    });

    test('toJson writes state names', () {
      const snapshot = DetailedMasterySnapshot(
        summary: MasterySnapshot(),
        conceptMastery: {'c1': MasteryState.fading},
      );

      expect(snapshot.toJson()['conceptMastery'], {'c1': 'fading'});
    });
  });
}
