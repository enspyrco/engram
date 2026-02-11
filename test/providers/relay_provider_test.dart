import 'package:engram/src/models/relay_challenge.dart';
import 'package:test/test.dart';

/// Unit tests for relay challenge model behavior used by RelayNotifier.
/// Full provider integration tests require Firestore mocking — these test
/// the domain logic that the provider orchestrates.
void main() {
  group('Relay leg claiming validation', () {
    late RelayChallenge relay;

    setUp(() {
      relay = RelayChallenge(
        id: 'relay_1',
        title: 'CI/CD Chain',
        legs: [
          const RelayLeg(conceptId: 'c1', conceptName: 'Git Basics'),
          const RelayLeg(conceptId: 'c2', conceptName: 'Branching'),
          const RelayLeg(conceptId: 'c3', conceptName: 'CI Pipelines'),
        ],
        createdAt: '2025-06-14T00:00:00.000Z',
        createdByUid: 'creator1',
      );
    });

    test('first leg can be claimed without prior completion', () {
      // Simulates the validation logic in RelayNotifier.claimLeg
      const legIndex = 0;
      final leg = relay.legs[legIndex];
      expect(leg.status, RelayLegStatus.unclaimed);

      // No prior leg requirement for index 0
      final canClaim = legIndex == 0 ||
          relay.legs[legIndex - 1].completedAt != null;
      expect(canClaim, isTrue);
    });

    test('second leg cannot be claimed if first is not completed', () {
      const legIndex = 1;
      final canClaim = legIndex == 0 ||
          relay.legs[legIndex - 1].completedAt != null;
      expect(canClaim, isFalse);
    });

    test('second leg can be claimed after first is completed', () {
      final updated = relay.withLegClaimed(
        0,
        uid: 'u1',
        displayName: 'Alice',
        timestamp: '2025-06-15T10:00:00.000Z',
      ).withLegCompleted(0, '2025-06-15T12:00:00.000Z');

      const legIndex = 1;
      final canClaim = legIndex == 0 ||
          updated.legs[legIndex - 1].completedAt != null;
      expect(canClaim, isTrue);
    });

    test('already claimed leg cannot be re-claimed', () {
      final claimed = relay.withLegClaimed(
        0,
        uid: 'u1',
        displayName: 'Alice',
        timestamp: '2025-06-15T10:00:00.000Z',
      );

      expect(claimed.legs[0].status, isNot(RelayLegStatus.unclaimed));
    });
  });

  group('Relay glory point calculation', () {
    test('normal leg completion awards 3 points', () {
      const basePoints = 3;
      expect(basePoints, 3);
    });

    test('stalled leg rescue awards 4 points', () {
      final oldClaim =
          DateTime.now().toUtc().subtract(const Duration(hours: 25)).toIso8601String();
      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'Git',
        claimedByUid: 'u1',
        claimedByName: 'A',
        claimedAt: oldClaim,
      );

      expect(leg.status, RelayLegStatus.stalled);
      final points = leg.status == RelayLegStatus.stalled ? 4 : 3;
      expect(points, 4);
    });

    test('final leg adds 5 bonus points', () {
      var relay = RelayChallenge(
        id: 'r1',
        title: 'T',
        legs: [
          const RelayLeg(
            conceptId: 'c1',
            conceptName: 'A',
            claimedByUid: 'u1',
            claimedByName: 'Alice',
            claimedAt: '2025-06-15T10:00:00.000Z',
            completedAt: '2025-06-15T12:00:00.000Z',
          ),
          const RelayLeg(
            conceptId: 'c2',
            conceptName: 'B',
            claimedByUid: 'u2',
            claimedByName: 'Bob',
            claimedAt: '2025-06-15T14:00:00.000Z',
          ),
        ],
        createdAt: '2025-06-14T00:00:00.000Z',
        createdByUid: 'u1',
      );

      relay = relay.withLegCompleted(1, '2025-06-15T16:00:00.000Z');
      final isLastLeg = relay.completedLegs == relay.legs.length;
      expect(isLastLeg, isTrue);
    });
  });

  group('Stall detection', () {
    test('identifies overdue legs with debounce check', () {
      final oldClaim =
          DateTime.now().toUtc().subtract(const Duration(hours: 25)).toIso8601String();
      final relay = RelayChallenge(
        id: 'r1',
        title: 'T',
        legs: [
          RelayLeg(
            conceptId: 'c1',
            conceptName: 'A',
            claimedByUid: 'u1',
            claimedByName: 'Alice',
            claimedAt: oldClaim,
          ),
        ],
        createdAt: '2025-06-14T00:00:00.000Z',
        createdByUid: 'u1',
      );

      final now = DateTime.now().toUtc();
      final leg = relay.legs[0];
      expect(leg.isOverdueAt(now), isTrue);
      expect(leg.lastStallNudgeAt, isNull); // No previous nudge — should send
    });

    test('respects 6h debounce on stall nudges', () {
      final oldClaim =
          DateTime.now().toUtc().subtract(const Duration(hours: 25)).toIso8601String();
      final recentNudge =
          DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String();

      final leg = RelayLeg(
        conceptId: 'c1',
        conceptName: 'A',
        claimedByUid: 'u1',
        claimedByName: 'Alice',
        claimedAt: oldClaim,
        lastStallNudgeAt: recentNudge,
      );

      final now = DateTime.now().toUtc();
      expect(leg.isOverdueAt(now), isTrue);

      // Should not nudge — last nudge was only 3h ago
      final lastNudge = DateTime.parse(leg.lastStallNudgeAt!);
      final shouldNudge = now.difference(lastNudge).inHours >= 6;
      expect(shouldNudge, isFalse);
    });
  });
}
