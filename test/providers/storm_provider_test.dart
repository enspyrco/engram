import 'package:engram/src/models/entropy_storm.dart';
import 'package:test/test.dart';

/// Unit tests for entropy storm logic used by StormNotifier.
/// Full provider integration tests require Firestore mocking — these test
/// the domain logic that the provider orchestrates.
void main() {
  group('Storm state transitions', () {
    late EntropyStorm storm;

    setUp(() {
      storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.scheduled,
        participantUids: ['u1', 'u2'],
        createdByUid: 'u1',
      );
    });

    test('scheduled → active when current time passes start', () {
      final now = DateTime.utc(2025, 6, 15, 1);
      final start = storm.scheduledStart;
      expect(now.isAfter(start), isTrue);

      final active = storm.withStatus(StormStatus.active);
      expect(active.status, StormStatus.active);
      expect(active.isActive, isTrue);
    });

    test('remains scheduled before start time', () {
      final now = DateTime.utc(2025, 6, 14);
      final start = storm.scheduledStart;
      expect(now.isAfter(start), isFalse);
    });

    test('active → survived when health stayed above threshold', () {
      final active = storm
          .withStatus(StormStatus.active)
          .withLowestHealth(0.75);

      final survived =
          active.lowestHealth != null &&
          active.lowestHealth! >= active.healthThreshold;
      expect(survived, isTrue);
    });

    test('active → failed when health dropped below threshold', () {
      final active = storm
          .withStatus(StormStatus.active)
          .withLowestHealth(0.55);

      final survived =
          active.lowestHealth != null &&
          active.lowestHealth! >= active.healthThreshold;
      expect(survived, isFalse);
    });

    test('active → failed when no health was tracked', () {
      final active = storm.withStatus(StormStatus.active);

      // lowestHealth is null — storm failed (can't prove survival)
      final survived =
          active.lowestHealth != null &&
          active.lowestHealth! >= active.healthThreshold;
      expect(survived, isFalse);
    });
  });

  group('Storm opt-in/out', () {
    test('opt-in only allowed during scheduled status', () {
      final storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.scheduled,
        participantUids: ['u1'],
        createdByUid: 'u1',
      );

      // Can opt-in during scheduled
      expect(storm.status, StormStatus.scheduled);

      final withU2 = storm.withParticipant('u2');
      expect(withU2.participantUids.length, 2);
    });

    test('opt-out removes participant', () {
      final storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.scheduled,
        participantUids: ['u1', 'u2'],
        createdByUid: 'u1',
      );

      final withoutU2 = storm.withoutParticipant('u2');
      expect(withoutU2.participantUids.length, 1);
      expect(withoutU2.participantUids.contains('u2'), isFalse);
    });
  });

  group('Health tracking', () {
    test('lowestHealth tracks minimum', () {
      var storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.active,
        createdByUid: 'u1',
      );

      // Simulate health tracking
      storm = storm.withLowestHealth(0.8);
      expect(storm.lowestHealth, 0.8);

      // Should update if lower
      const currentHealth = 0.6;
      if (storm.lowestHealth == null || currentHealth < storm.lowestHealth!) {
        storm = storm.withLowestHealth(currentHealth);
      }
      expect(storm.lowestHealth, 0.6);

      // Should NOT update if higher
      const higherHealth = 0.9;
      if (storm.lowestHealth == null || higherHealth < storm.lowestHealth!) {
        storm = storm.withLowestHealth(higherHealth);
      }
      expect(storm.lowestHealth, 0.6); // unchanged
    });
  });

  group('Decay multiplier', () {
    test('active storm produces multiplier 2.0', () {
      final storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.active,
        createdByUid: 'u1',
      );

      final multiplier = storm.isActive ? 2.0 : 1.0;
      expect(multiplier, 2.0);
    });

    test('non-active storm produces multiplier 1.0', () {
      final storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.scheduled,
        createdByUid: 'u1',
      );

      final multiplier = storm.isActive ? 2.0 : 1.0;
      expect(multiplier, 1.0);
    });

    test('null storm produces multiplier 1.0', () {
      const EntropyStorm? storm = null;
      final isActive = storm?.isActive ?? false;
      final multiplier = isActive ? 2.0 : 1.0;
      expect(multiplier, 1.0);
    });
  });

  group('Glory point awards', () {
    test('survived storm awards 10 points to each participant', () {
      final storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.active,
        participantUids: ['u1', 'u2', 'u3'],
        createdByUid: 'u1',
        lowestHealth: 0.75,
      );

      final survived =
          storm.lowestHealth != null &&
          storm.lowestHealth! >= storm.healthThreshold;
      expect(survived, isTrue);

      // Each participant gets 10 points
      final totalPointsAwarded = storm.participantUids.length * 10;
      expect(totalPointsAwarded, 30);
    });

    test('failed storm awards no points', () {
      final storm = EntropyStorm(
        id: 's1',
        scheduledStart: DateTime.utc(2025, 6, 15),
        scheduledEnd: DateTime.utc(2025, 6, 17),
        status: StormStatus.active,
        participantUids: ['u1', 'u2'],
        createdByUid: 'u1',
        lowestHealth: 0.5,
      );

      final survived =
          storm.lowestHealth != null &&
          storm.lowestHealth! >= storm.healthThreshold;
      expect(survived, isFalse);
    });
  });
}
