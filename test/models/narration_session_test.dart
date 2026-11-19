import 'dart:typed_data';

import 'package:engram/src/models/narration_script.dart';
import 'package:engram/src/models/narration_session.dart';
import 'package:engram/src/models/timestamped_concept.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConceptMarker', () {
    test('stores character offsets for a concept', () {
      const marker = ConceptMarker(
        conceptId: 'spaced-rep',
        startChar: 10,
        endChar: 25,
      );

      expect(marker.conceptId, 'spaced-rep');
      expect(marker.startChar, 10);
      expect(marker.endChar, 25);
    });

    test('equality based on all fields', () {
      const a = ConceptMarker(conceptId: 'a', startChar: 0, endChar: 5);
      const b = ConceptMarker(conceptId: 'a', startChar: 0, endChar: 5);
      const c = ConceptMarker(conceptId: 'a', startChar: 0, endChar: 10);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('TimestampedConcept', () {
    test('stores time range for a concept', () {
      const tc = TimestampedConcept(
        conceptId: 'neural-nets',
        startTime: 1.5,
        endTime: 4.2,
      );

      expect(tc.conceptId, 'neural-nets');
      expect(tc.startTime, 1.5);
      expect(tc.endTime, 4.2);
    });

    test('containsPosition returns true within range', () {
      const tc = TimestampedConcept(
        conceptId: 'c1',
        startTime: 2.0,
        endTime: 5.0,
      );

      expect(tc.containsPosition(2.0), isTrue); // start boundary
      expect(tc.containsPosition(3.5), isTrue); // middle
      expect(tc.containsPosition(5.0), isTrue); // end boundary
    });

    test('containsPosition returns false outside range', () {
      const tc = TimestampedConcept(
        conceptId: 'c1',
        startTime: 2.0,
        endTime: 5.0,
      );

      expect(tc.containsPosition(1.9), isFalse);
      expect(tc.containsPosition(5.1), isFalse);
    });

    test('equality based on all fields', () {
      const a = TimestampedConcept(
        conceptId: 'c1',
        startTime: 1.0,
        endTime: 2.0,
      );
      const b = TimestampedConcept(
        conceptId: 'c1',
        startTime: 1.0,
        endTime: 2.0,
      );
      const c = TimestampedConcept(
        conceptId: 'c1',
        startTime: 1.0,
        endTime: 3.0,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('NarrationPhase', () {
    test('has all expected values', () {
      expect(
        NarrationPhase.values,
        containsAll([
          NarrationPhase.idle,
          NarrationPhase.generatingScript,
          NarrationPhase.synthesizingAudio,
          NarrationPhase.ready,
          NarrationPhase.playing,
          NarrationPhase.paused,
          NarrationPhase.completed,
          NarrationPhase.error,
        ]),
      );
    });
  });

  group('NarrationSession', () {
    test('default state is idle with empty collections', () {
      const session = NarrationSession();

      expect(session.phase, NarrationPhase.idle);
      expect(session.scriptText, isEmpty);
      expect(session.timestampedConcepts, isEmpty);
      expect(session.audioBytes, isNull);
      expect(session.durationSeconds, 0.0);
      expect(session.positionSeconds, 0.0);
      expect(session.activeConcepts, isEmpty);
      expect(session.errorMessage, isEmpty);
    });

    test('copyWith updates specified fields', () {
      const initial = NarrationSession();
      final updated = initial.copyWith(
        phase: NarrationPhase.generatingScript,
        scriptText: 'The concept of spaced repetition...',
      );

      expect(updated.phase, NarrationPhase.generatingScript);
      expect(updated.scriptText, 'The concept of spaced repetition...');
      // Unchanged fields remain default.
      expect(updated.audioBytes, isNull);
      expect(updated.durationSeconds, 0.0);
    });

    test('copyWith preserves unspecified fields', () {
      final session = NarrationSession(
        phase: NarrationPhase.playing,
        scriptText: 'Hello world',
        durationSeconds: 45.0,
        positionSeconds: 12.5,
        activeConcepts: ISet(const {'concept-a', 'concept-b'}),
      );

      final updated = session.copyWith(positionSeconds: 20.0);

      expect(updated.phase, NarrationPhase.playing);
      expect(updated.scriptText, 'Hello world');
      expect(updated.durationSeconds, 45.0);
      expect(updated.positionSeconds, 20.0);
      expect(updated.activeConcepts, hasLength(2));
    });

    test('copyWith with timestamped concepts', () {
      const initial = NarrationSession();
      final updated = initial.copyWith(
        timestampedConcepts: IList(const [
          TimestampedConcept(conceptId: 'a', startTime: 0.0, endTime: 2.0),
          TimestampedConcept(conceptId: 'b', startTime: 2.0, endTime: 4.0),
        ]),
      );

      expect(updated.timestampedConcepts, hasLength(2));
      expect(updated.timestampedConcepts[0].conceptId, 'a');
    });

    test('copyWith with audioBytes', () {
      const initial = NarrationSession();
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02]);
      final updated = initial.copyWith(
        phase: NarrationPhase.ready,
        audioBytes: bytes,
      );

      expect(updated.audioBytes, isNotNull);
      expect(updated.audioBytes!.length, 3);
    });

    test('phase transitions follow expected flow', () {
      var session = const NarrationSession();

      // idle → generatingScript
      session = session.copyWith(phase: NarrationPhase.generatingScript);
      expect(session.phase, NarrationPhase.generatingScript);

      // generatingScript → synthesizingAudio
      session = session.copyWith(phase: NarrationPhase.synthesizingAudio);
      expect(session.phase, NarrationPhase.synthesizingAudio);

      // synthesizingAudio → ready
      session = session.copyWith(phase: NarrationPhase.ready);
      expect(session.phase, NarrationPhase.ready);

      // ready → playing
      session = session.copyWith(phase: NarrationPhase.playing);
      expect(session.phase, NarrationPhase.playing);

      // playing → paused
      session = session.copyWith(phase: NarrationPhase.paused);
      expect(session.phase, NarrationPhase.paused);

      // paused → playing
      session = session.copyWith(phase: NarrationPhase.playing);
      expect(session.phase, NarrationPhase.playing);

      // playing → completed
      session = session.copyWith(phase: NarrationPhase.completed);
      expect(session.phase, NarrationPhase.completed);
    });

    test('error phase includes message', () {
      const session = NarrationSession();
      final errored = session.copyWith(
        phase: NarrationPhase.error,
        errorMessage: 'ElevenLabs API rate limit exceeded',
      );

      expect(errored.phase, NarrationPhase.error);
      expect(errored.errorMessage, contains('rate limit'));
    });
  });
}
