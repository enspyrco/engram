import 'package:engram/src/models/relay_challenge.dart';
import 'package:test/test.dart';

void main() {
  group('RelayLeg', () {
    test('fromJson/toJson round-trip', () {
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git Basics',
        claimedByUid: 'user1',
        claimedByName: 'Alice',
        claimedAt: DateTime.utc(2025, 6, 15, 10),
        completedAt: DateTime.utc(2025, 6, 15, 12),
        lastStallNudgeAt: DateTime.utc(2025, 6, 15, 11),
      );

      final json = leg.toJson();
      final restored = RelayLeg.fromJson(json);

      expect(restored.conceptId, 'c1');
      expect(restored.conceptName, 'Git Basics');
      expect(restored.claimedByUid, 'user1');
      expect(restored.claimedByName, 'Alice');
      expect(restored.claimedAt, DateTime.utc(2025, 6, 15, 10));
      expect(restored.completedAt, DateTime.utc(2025, 6, 15, 12));
      expect(restored.lastStallNudgeAt, DateTime.utc(2025, 6, 15, 11));
    });

    test('statusAt is unclaimed when no claim', () {
      const leg = RelayLeg(conceptId: 'c1', conceptName: 'Git');
      final now = DateTime.utc(2025, 6, 15);
      expect(leg.statusAt(now), RelayLegStatus.unclaimed);
    });

    test('statusAt is claimed when claimed and within deadline', () {
      final now = DateTime.utc(2025, 6, 15, 11);
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: DateTime.utc(2025, 6, 15, 10),
      );
      expect(leg.statusAt(now), RelayLegStatus.claimed);
    });

    test('statusAt is stalled when overdue', () {
      final now = DateTime.utc(2025, 6, 15, 10); // 26h later
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: DateTime.utc(2025, 6, 14, 8),
      );
      expect(leg.statusAt(now), RelayLegStatus.stalled);
    });

    test('statusAt is completed when completedAt set', () {
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: DateTime.utc(2020),
        completedAt: DateTime.utc(2020, 1, 1, 12),
      );
      final now = DateTime.utc(2025, 6, 15);
      expect(leg.statusAt(now), RelayLegStatus.completed);
    });

    test('deadline is 24 hours after claimedAt', () {
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: DateTime.utc(2025, 6, 15, 10),
      );
      expect(leg.deadline, DateTime.utc(2025, 6, 16, 10, 0, 0));
    });

    test('deadline is null when unclaimed', () {
      const leg = RelayLeg(conceptId: 'c1', conceptName: 'Git');
      expect(leg.deadline, isNull);
    });

    test('isOverdueAt uses provided time', () {
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: DateTime.utc(2025, 6, 15, 10),
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
        timestamp: DateTime.utc(2025, 6, 15, 10),
      );
      expect(claimed.claimedByUid, 'u1');
      expect(claimed.claimedByName, 'Alice');
      expect(claimed.claimedAt, DateTime.utc(2025, 6, 15, 10));
      expect(leg.claimedByUid, isNull); // original unchanged
    });

    test('withCompleted creates new leg with completion', () {
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: DateTime.utc(2025, 6, 15, 10),
      );
      final completed = leg.withCompleted(DateTime.utc(2025, 6, 15, 12));
      expect(completed.completedAt, DateTime.utc(2025, 6, 15, 12));
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
          RelayLeg(
            conceptId: 'c2',
            conceptName: 'Branching',
            claimedByUid: 'u1',
            claimedByName: 'Alice',
            claimedAt: DateTime.utc(2025, 6, 15, 10),
            completedAt: DateTime.utc(2025, 6, 15, 12),
          ),
          const RelayLeg(conceptId: 'c3', conceptName: 'CI Pipelines'),
        ],
        createdAt: DateTime.utc(2025, 6, 14),
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
      final completed = relay.withCompleted(DateTime.utc(2025, 6, 16));
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
        timestamp: DateTime.utc(2025, 6, 15, 14),
      );
      expect(updated.legs[0].claimedByUid, 'u2');
      expect(updated.legs[1].claimedByUid, 'u1'); // other legs unchanged
      expect(relay.legs[0].claimedByUid, isNull); // original unchanged
    });

    test('withLegCompleted updates specific leg', () {
      final updated = relay.withLegCompleted(0, DateTime.utc(2025, 6, 15, 15));
      expect(updated.legs[0].completedAt, DateTime.utc(2025, 6, 15, 15));
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
        createdAt: DateTime.utc(2025),
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
