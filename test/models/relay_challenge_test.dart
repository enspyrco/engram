import 'package:engram/src/models/relay_challenge.dart';
import 'package:test/test.dart';

void main() {
  group('RelayLeg', () {
    test('fromJson/toJson round-trip', () {
      const leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git Basics',
        claimedByUid: 'user1',
        claimedByName: 'Alice',
        claimedAt: '2025-06-15T10:00:00.000Z',
        completedAt: '2025-06-15T12:00:00.000Z',
        lastStallNudgeAt: '2025-06-15T11:00:00.000Z',
      );

      final json = leg.toJson();
      final restored = RelayLeg.fromJson(json);

      expect(restored.conceptId, 'c1');
      expect(restored.conceptName, 'Git Basics');
      expect(restored.claimedByUid, 'user1');
      expect(restored.claimedByName, 'Alice');
      expect(restored.claimedAt, '2025-06-15T10:00:00.000Z');
      expect(restored.completedAt, '2025-06-15T12:00:00.000Z');
      expect(restored.lastStallNudgeAt, '2025-06-15T11:00:00.000Z');
    });

    test('statusAt is unclaimed when no claim', () {
      const leg = RelayLeg(conceptId: 'c1', conceptName: 'Git');
      final now = DateTime.utc(2025, 6, 15);
      expect(leg.statusAt(now), RelayLegStatus.unclaimed);
    });

    test('statusAt is claimed when claimed and within deadline', () {
      final now = DateTime.utc(2025, 6, 15, 11);
      final recentClaim = DateTime.utc(2025, 6, 15, 10).toIso8601String();
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: recentClaim,
      );
      expect(leg.statusAt(now), RelayLegStatus.claimed);
    });

    test('statusAt is stalled when overdue', () {
      final claimedAt = DateTime.utc(2025, 6, 14, 8).toIso8601String();
      final now = DateTime.utc(2025, 6, 15, 10); // 26h later
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: claimedAt,
      );
      expect(leg.statusAt(now), RelayLegStatus.stalled);
    });

    test('statusAt is completed when completedAt set', () {
      const leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: '2020-01-01T00:00:00.000Z',
        completedAt: '2020-01-01T12:00:00.000Z',
      );
      final now = DateTime.utc(2025, 6, 15);
      expect(leg.statusAt(now), RelayLegStatus.completed);
    });

    test('deadline is 24 hours after claimedAt', () {
      const leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: '2025-06-15T10:00:00.000Z',
      );
      expect(leg.deadline, DateTime.utc(2025, 6, 16, 10, 0, 0));
    });

    test('deadline is null when unclaimed', () {
      const leg = RelayLeg(conceptId: 'c1', conceptName: 'Git');
      expect(leg.deadline, isNull);
    });

    test('isOverdueAt uses provided time', () {
      const leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: '2025-06-15T10:00:00.000Z',
      );
      // 23 hours later — not overdue
      expect(leg.isOverdueAt(DateTime.utc(2025, 6, 16, 9)), isFalse);
      // 25 hours later — overdue
      expect(leg.isOverdueAt(DateTime.utc(2025, 6, 16, 11)), isTrue);
    });

    test('withClaimed creates new leg with claim info', () {
      const leg = RelayLeg(conceptId: 'c1', conceptName: 'Git');
      final claimed = leg.withClaimed(
        uid: 'u1',
        displayName: 'Alice',
        timestamp: '2025-06-15T10:00:00.000Z',
      );
      expect(claimed.claimedByUid, 'u1');
      expect(claimed.claimedByName, 'Alice');
      expect(claimed.claimedAt, '2025-06-15T10:00:00.000Z');
      expect(leg.claimedByUid, isNull); // original unchanged
    });

    test('withCompleted creates new leg with completion', () {
      const leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: '2025-06-15T10:00:00.000Z',
      );
      final completed = leg.withCompleted('2025-06-15T12:00:00.000Z');
      expect(completed.completedAt, '2025-06-15T12:00:00.000Z');
      expect(leg.completedAt, isNull);
    });
  });

  group('RelayChallenge', () {
    late RelayChallenge relay;

    setUp(() {
      relay = RelayChallenge(
        id: 'relay_1',
        title: 'CI/CD Pipeline',
        legs: [
          const RelayLeg(conceptId: 'c1', conceptName: 'Git Basics'),
          const RelayLeg(
            conceptId: 'c2',
            conceptName: 'Branching',
            claimedByUid: 'u1',
            claimedByName: 'Alice',
            claimedAt: '2025-06-15T10:00:00.000Z',
            completedAt: '2025-06-15T12:00:00.000Z',
          ),
          const RelayLeg(conceptId: 'c3', conceptName: 'CI Pipelines'),
        ],
        createdAt: '2025-06-14T00:00:00.000Z',
        createdByUid: 'creator1',
      );
    });

    test('fromJson/toJson round-trip', () {
      final json = relay.toJson();
      final restored = RelayChallenge.fromJson(json);

      expect(restored.id, 'relay_1');
      expect(restored.title, 'CI/CD Pipeline');
      expect(restored.legs.length, 3);
      expect(restored.legs[1].claimedByUid, 'u1');
      expect(restored.createdByUid, 'creator1');
      expect(restored.completedAt, isNull);
    });

    test('isComplete is false when no completedAt', () {
      expect(relay.isComplete, isFalse);
    });

    test('isComplete is true when completedAt set', () {
      final completed = relay.withCompleted('2025-06-16T00:00:00.000Z');
      expect(completed.isComplete, isTrue);
    });

    test('completedLegs counts completed legs', () {
      expect(relay.completedLegs, 1); // only leg[1] is completed
    });

    test('currentLegIndex returns first uncompleted', () {
      // leg[0] is unclaimed, so it's the current leg
      expect(relay.currentLegIndex, 0);
    });

    test('progress reflects completion ratio', () {
      expect(relay.progress, closeTo(1 / 3, 0.01));
    });

    test('withLegClaimed updates specific leg', () {
      final updated = relay.withLegClaimed(
        0,
        uid: 'u2',
        displayName: 'Bob',
        timestamp: '2025-06-15T14:00:00.000Z',
      );
      expect(updated.legs[0].claimedByUid, 'u2');
      expect(updated.legs[1].claimedByUid, 'u1'); // other legs unchanged
      expect(relay.legs[0].claimedByUid, isNull); // original unchanged
    });

    test('withLegCompleted updates specific leg', () {
      final updated = relay.withLegCompleted(0, '2025-06-15T15:00:00.000Z');
      expect(updated.legs[0].completedAt, '2025-06-15T15:00:00.000Z');
    });

    test('hasStallAt detects stalled legs', () {
      // No stalls in the fixture (leg[0] unclaimed, leg[1] completed, leg[2] unclaimed)
      final now = DateTime.utc(2025, 6, 15);
      expect(relay.hasStallAt(now), isFalse);
    });

    test('empty legs yields progress 1.0', () {
      final empty = RelayChallenge(
        id: 'r',
        title: 'T',
        createdAt: '2025-01-01T00:00:00.000Z',
        createdByUid: 'u',
      );
      expect(empty.progress, 1.0);
    });

    test('fromJson handles missing legs', () {
      final restored = RelayChallenge.fromJson(const {
        'id': 'r',
        'title': 'T',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'createdByUid': 'u',
      });
      expect(restored.legs.isEmpty, isTrue);
    });
  });
}
