import 'package:engram/src/engine/timestamp_mapper.dart';
import 'package:engram/src/models/narration_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapMarkersToTimestamps', () {
    test('maps a single marker to time range', () {
      // 10-character text: "Hello World" (indices 0–9)
      // Character start times: each char ~0.1s apart
      final startTimes = List.generate(10, (i) => i * 0.1);
      final endTimes = List.generate(10, (i) => (i + 1) * 0.1);

      // Marker covers chars 6–9 ("World" minus the 'd' at 10)
      const markers = [
        ConceptMarker(conceptId: 'greeting', startChar: 6, endChar: 10),
      ];

      final result = mapMarkersToTimestamps(
        markers: markers,
        characterStartTimes: startTimes,
        characterEndTimes: endTimes,
      );

      expect(result, hasLength(1));
      expect(result[0].conceptId, 'greeting');
      expect(result[0].startTime, closeTo(0.6, 0.001)); // char 6 start
      expect(result[0].endTime, closeTo(1.0, 0.001)); // char 9 end
    });

    test('maps multiple markers to separate time ranges', () {
      // 20-character text, uniform timing
      final startTimes = List.generate(20, (i) => i * 0.05);
      final endTimes = List.generate(20, (i) => (i + 1) * 0.05);

      const markers = [
        ConceptMarker(conceptId: 'a', startChar: 0, endChar: 5),
        ConceptMarker(conceptId: 'b', startChar: 10, endChar: 15),
      ];

      final result = mapMarkersToTimestamps(
        markers: markers,
        characterStartTimes: startTimes,
        characterEndTimes: endTimes,
      );

      expect(result, hasLength(2));
      expect(result[0].conceptId, 'a');
      expect(result[0].startTime, closeTo(0.0, 0.001));
      expect(result[0].endTime, closeTo(0.25, 0.001));
      expect(result[1].conceptId, 'b');
      expect(result[1].startTime, closeTo(0.5, 0.001));
      expect(result[1].endTime, closeTo(0.75, 0.001));
    });

    test('clamps endChar to timestamp array bounds', () {
      // Only 5 characters of timing data
      final startTimes = [0.0, 0.1, 0.2, 0.3, 0.4];
      final endTimes = [0.1, 0.2, 0.3, 0.4, 0.5];

      // Marker extends beyond available data (endChar = 10)
      const markers = [
        ConceptMarker(conceptId: 'overflow', startChar: 2, endChar: 10),
      ];

      final result = mapMarkersToTimestamps(
        markers: markers,
        characterStartTimes: startTimes,
        characterEndTimes: endTimes,
      );

      expect(result, hasLength(1));
      expect(result[0].startTime, closeTo(0.2, 0.001));
      // Clamped to last available end time
      expect(result[0].endTime, closeTo(0.5, 0.001));
    });

    test('clamps startChar to timestamp array bounds', () {
      final startTimes = [0.0, 0.1, 0.2];
      final endTimes = [0.1, 0.2, 0.3];

      // startChar beyond array length
      const markers = [
        ConceptMarker(conceptId: 'beyond', startChar: 5, endChar: 8),
      ];

      final result = mapMarkersToTimestamps(
        markers: markers,
        characterStartTimes: startTimes,
        characterEndTimes: endTimes,
      );

      // Should handle gracefully — use last available times
      expect(result, hasLength(1));
      expect(result[0].startTime, closeTo(0.2, 0.001));
      expect(result[0].endTime, closeTo(0.3, 0.001));
    });

    test('returns empty list for empty markers', () {
      final result = mapMarkersToTimestamps(
        markers: const [],
        characterStartTimes: [0.0, 0.1],
        characterEndTimes: [0.1, 0.2],
      );

      expect(result, isEmpty);
    });

    test('returns empty list for empty timing data', () {
      const markers = [ConceptMarker(conceptId: 'a', startChar: 0, endChar: 5)];

      final result = mapMarkersToTimestamps(
        markers: markers,
        characterStartTimes: const [],
        characterEndTimes: const [],
      );

      expect(result, isEmpty);
    });

    test('handles zero-length marker (startChar == endChar)', () {
      final startTimes = [0.0, 0.1, 0.2, 0.3];
      final endTimes = [0.1, 0.2, 0.3, 0.4];

      const markers = [
        ConceptMarker(conceptId: 'point', startChar: 2, endChar: 2),
      ];

      final result = mapMarkersToTimestamps(
        markers: markers,
        characterStartTimes: startTimes,
        characterEndTimes: endTimes,
      );

      // A zero-width marker maps to the character at startChar position.
      // startTime comes from characterStartTimes, endTime from characterEndTimes.
      expect(result, hasLength(1));
      expect(result[0].startTime, closeTo(0.2, 0.001)); // startTimes[2]
      expect(result[0].endTime, closeTo(0.3, 0.001)); // endTimes[2]
    });
  });
}
