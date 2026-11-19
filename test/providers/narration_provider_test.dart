import 'dart:typed_data';

import 'package:engram/src/engine/concept_marker_parser.dart';
import 'package:engram/src/engine/timestamp_mapper.dart';
import 'package:engram/src/models/narration_session.dart';
import 'package:engram/src/models/timestamped_concept.dart';
import 'package:engram/src/providers/narration_provider.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  group('computeActiveConcepts', () {
    // Helper: create timestamped concepts.
    final concepts = [
      const TimestampedConcept(conceptId: 'a', startTime: 0.0, endTime: 2.0),
      const TimestampedConcept(conceptId: 'b', startTime: 1.5, endTime: 4.0),
      const TimestampedConcept(conceptId: 'c', startTime: 5.0, endTime: 7.0),
    ];

    test('returns concepts active at current position', () {
      // At t=1.0, only 'a' is active (0.0–2.0)
      final result = computeActiveConcepts(concepts, 1.0);
      expect(result, equals({'a'}));
    });

    test('returns overlapping concepts', () {
      // At t=1.8, both 'a' (0.0–2.0) and 'b' (1.5–4.0) are active
      final result = computeActiveConcepts(concepts, 1.8);
      expect(result, equals({'a', 'b'}));
    });

    test('returns empty set when no concept is active', () {
      // At t=4.5, gap between 'b' (ends 4.0) and 'c' (starts 5.0)
      final result = computeActiveConcepts(concepts, 4.5);
      expect(result, isEmpty);
    });

    test('handles boundary — exact start time', () {
      final result = computeActiveConcepts(concepts, 5.0);
      expect(result, equals({'c'}));
    });

    test('handles boundary — exact end time', () {
      final result = computeActiveConcepts(concepts, 2.0);
      expect(result, contains('a'));
    });

    test('returns empty set for empty concepts list', () {
      final result = computeActiveConcepts([], 1.0);
      expect(result, isEmpty);
    });
  });

  group('NarrationSession pipeline integration', () {
    test('full pipeline: parse → map → session state', () {
      // Simulate the full pipeline without audio player.
      const annotatedText =
          '[CONCEPT:spaced-rep]Spaced repetition[/CONCEPT] is a technique '
          'that uses the [CONCEPT:forgetting-curve]forgetting curve[/CONCEPT].';

      // 1. Parse markers.
      final parseResult = parseConceptMarkers(annotatedText);
      expect(parseResult.markers, hasLength(2));
      expect(parseResult.strippedText, isNot(contains('[CONCEPT')));

      // 2. Fake character-level timing data (1 char = 0.02s).
      final charCount = parseResult.strippedText.length;
      final startTimes = List.generate(charCount, (i) => i * 0.02);
      final endTimes = List.generate(charCount, (i) => (i + 1) * 0.02);

      // 3. Map markers to timestamps.
      final timestamped = mapMarkersToTimestamps(
        markers: parseResult.markers,
        characterStartTimes: startTimes,
        characterEndTimes: endTimes,
      );
      expect(timestamped, hasLength(2));
      expect(timestamped[0].conceptId, 'spaced-rep');
      expect(timestamped[1].conceptId, 'forgetting-curve');

      // 4. Build session state.
      final session = NarrationSession(
        phase: NarrationPhase.ready,
        scriptText: parseResult.strippedText,
        timestampedConcepts: IList(timestamped),
        audioBytes: Uint8List(100), // fake audio
        durationSeconds: endTimes.last,
      );

      expect(session.phase, NarrationPhase.ready);
      expect(session.timestampedConcepts, hasLength(2));

      // 5. Compute active concepts at different positions.
      final midFirst =
          timestamped[0].startTime +
          (timestamped[0].endTime - timestamped[0].startTime) / 2;
      final activeAtMid = computeActiveConcepts(
        session.timestampedConcepts.toList(),
        midFirst,
      );
      expect(activeAtMid, contains('spaced-rep'));
    });
  });
}
