import 'package:engram/src/models/entropy_storm.dart';
import 'package:test/test.dart';

void main() {
  group('EntropyStorm', () {
    late EntropyStorm storm;

    setUp(() {
      storm = EntropyStorm(
        id: 'storm_1',
        scheduledStart: '2025-06-15T00:00:00.000Z',
        scheduledEnd: '2025-06-17T00:00:00.000Z',
        status: StormStatus.scheduled,
        participantUids: ['u1', 'u2'],
        createdByUid: 'u1',
      );
    });

    test('fromJson/toJson round-trip', () {
      final json = storm.toJson();
      final restored = EntropyStorm.fromJson(json);

      expect(restored.id, 'storm_1');
      expect(restored.scheduledStart, '2025-06-15T00:00:00.000Z');
      expect(restored.scheduledEnd, '2025-06-17T00:00:00.000Z');
      expect(restored.healthThreshold, 0.7);
      expect(restored.status, StormStatus.scheduled);
      expect(restored.participantUids.length, 2);
      expect(restored.createdByUid, 'u1');
    });

    test('fromJson handles missing optional fields', () {
      final restored = EntropyStorm.fromJson(const {
        'id': 's1',
        'scheduledStart': '2025-06-15T00:00:00.000Z',
        'scheduledEnd': '2025-06-17T00:00:00.000Z',
        'status': 'scheduled',
        'createdByUid': 'u1',
      });

      expect(restored.healthThreshold, 0.7);
      expect(restored.lowestHealth, isNull);
      expect(restored.participantUids.isEmpty, isTrue);
    });

    test('isActive reflects status', () {
      expect(storm.isActive, isFalse);
      final active = storm.withStatus(StormStatus.active);
      expect(active.isActive, isTrue);
    });

    test('isActiveAt checks time window', () {
      final active = storm.withStatus(StormStatus.active);

      // During storm
      expect(active.isActiveAt(DateTime.utc(2025, 6, 16)), isTrue);
      // Before storm
      expect(active.isActiveAt(DateTime.utc(2025, 6, 14)), isFalse);
      // After storm
      expect(active.isActiveAt(DateTime.utc(2025, 6, 18)), isFalse);
    });

    test('isActiveAt returns false for survived/failed', () {
      final survived = storm.withStatus(StormStatus.survived);
      expect(survived.isActiveAt(DateTime.utc(2025, 6, 16)), isFalse);
    });

    test('remainingDuration computes correctly', () {
      final active = storm.withStatus(StormStatus.active);
      final remaining = active.remainingDuration(
        now: DateTime.utc(2025, 6, 16),
      );
      expect(remaining, const Duration(hours: 24));
    });

    test('remainingDuration is zero after end', () {
      final remaining = storm.remainingDuration(
        now: DateTime.utc(2025, 6, 18),
      );
      expect(remaining, Duration.zero);
    });

    test('timeUntilStart computes correctly', () {
      final until = storm.timeUntilStart(
        now: DateTime.utc(2025, 6, 14),
      );
      expect(until, const Duration(hours: 24));
    });

    test('timeUntilStart is zero after start', () {
      final until = storm.timeUntilStart(
        now: DateTime.utc(2025, 6, 16),
      );
      expect(until, Duration.zero);
    });

    test('withParticipant adds uid', () {
      final updated = storm.withParticipant('u3');
      expect(updated.participantUids.length, 3);
      expect(updated.participantUids.contains('u3'), isTrue);
    });

    test('withParticipant is idempotent', () {
      final updated = storm.withParticipant('u1');
      expect(updated.participantUids.length, 2);
    });

    test('withoutParticipant removes uid', () {
      final updated = storm.withoutParticipant('u2');
      expect(updated.participantUids.length, 1);
      expect(updated.participantUids.contains('u2'), isFalse);
    });

    test('withStatus creates new instance', () {
      final active = storm.withStatus(StormStatus.active);
      expect(active.status, StormStatus.active);
      expect(storm.status, StormStatus.scheduled);
    });

    test('withLowestHealth creates new instance', () {
      final updated = storm.withLowestHealth(0.55);
      expect(updated.lowestHealth, 0.55);
      expect(storm.lowestHealth, isNull);
    });

    test('default healthThreshold is 0.7', () {
      expect(storm.healthThreshold, 0.7);
    });
  });
}
