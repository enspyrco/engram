import 'package:engram/src/models/repair_mission.dart';
import 'package:test/test.dart';

void main() {
  group('RepairMission', () {
    final now = DateTime.utc(2025, 6, 15, 12, 0);

    test('withReviewedConcept adds concept and passes caller timestamp', () {
      const mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b', 'c'],
        createdAt: '2025-06-15T00:00:00.000Z',
      );

      final updated = mission.withReviewedConcept('a', now: now);

      expect(updated.reviewedConceptIds, ['a']);
      expect(updated.isComplete, isFalse);
      expect(updated.completedAt, isNull);
    });

    test('withReviewedConcept sets completedAt on last concept', () {
      const mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        reviewedConceptIds: ['a'],
        createdAt: '2025-06-15T00:00:00.000Z',
      );

      final completed = mission.withReviewedConcept('b', now: now);

      expect(completed.isComplete, isTrue);
      expect(completed.completedAt, now.toUtc().toIso8601String());
    });

    test('withReviewedConcept ignores duplicate concept', () {
      const mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        reviewedConceptIds: ['a'],
        createdAt: '2025-06-15T00:00:00.000Z',
      );

      final same = mission.withReviewedConcept('a', now: now);

      expect(identical(same, mission), isTrue);
    });

    test('withReviewedConcept ignores concept not in conceptIds', () {
      const mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        createdAt: '2025-06-15T00:00:00.000Z',
      );

      final same = mission.withReviewedConcept('z', now: now);

      expect(identical(same, mission), isTrue);
    });

    test('progress and remaining are correct', () {
      const mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b', 'c', 'd'],
        reviewedConceptIds: ['a'],
        createdAt: '2025-06-15T00:00:00.000Z',
      );

      expect(mission.progress, 0.25);
      expect(mission.remaining, 3);
    });

    test('JSON round-trip', () {
      const mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        reviewedConceptIds: ['a'],
        createdAt: '2025-06-15T00:00:00.000Z',
        completedAt: null,
        catastropheEventId: 'evt1',
      );

      final json = mission.toJson();
      final restored = RepairMission.fromJson(json);

      expect(restored.id, mission.id);
      expect(restored.conceptIds, mission.conceptIds);
      expect(restored.reviewedConceptIds, mission.reviewedConceptIds);
      expect(restored.createdAt, mission.createdAt);
      expect(restored.catastropheEventId, mission.catastropheEventId);
    });
  });
}
