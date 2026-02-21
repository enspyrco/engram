import 'package:engram/src/models/repair_mission.dart';
import 'package:test/test.dart';

void main() {
  group('RepairMission', () {
    final now = DateTime.utc(2025, 6, 15, 12, 0);

    test('withReviewedConcept adds concept and passes caller timestamp', () {
      final mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b', 'c'],
        createdAt: DateTime.utc(2025, 6, 15),
      );

      final updated = mission.withReviewedConcept('a', now: now);

      expect(updated.reviewedConceptIds, ['a']);
      expect(updated.isComplete, isFalse);
      expect(updated.completedAt, isNull);
    });

    test('withReviewedConcept sets completedAt on last concept', () {
      final mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        reviewedConceptIds: ['a'],
        createdAt: DateTime.utc(2025, 6, 15),
      );

      final completed = mission.withReviewedConcept('b', now: now);

      expect(completed.isComplete, isTrue);
      expect(completed.completedAt, now.toUtc());
    });

    test('withReviewedConcept ignores duplicate concept', () {
      final mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        reviewedConceptIds: ['a'],
        createdAt: DateTime.utc(2025, 6, 15),
      );

      final same = mission.withReviewedConcept('a', now: now);

      expect(identical(same, mission), isTrue);
    });

    test('withReviewedConcept ignores concept not in conceptIds', () {
      final mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        createdAt: DateTime.utc(2025, 6, 15),
      );

      final same = mission.withReviewedConcept('z', now: now);

      expect(identical(same, mission), isTrue);
    });

    test('progress and remaining are correct', () {
      final mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b', 'c', 'd'],
        reviewedConceptIds: ['a'],
        createdAt: DateTime.utc(2025, 6, 15),
      );

      expect(mission.progress, 0.25);
      expect(mission.remaining, 3);
    });

    test('JSON round-trip', () {
      final mission = RepairMission(
        id: 'm1',
        conceptIds: ['a', 'b'],
        reviewedConceptIds: ['a'],
        createdAt: DateTime.utc(2025, 6, 15),
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
