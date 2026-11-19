import 'package:engram/src/engine/concept_marker_parser.dart';
import 'package:engram/src/models/narration_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseConceptMarkers', () {
    test('extracts a single concept marker', () {
      const input =
          'Learn about [CONCEPT:spaced-rep]spaced repetition[/CONCEPT] today.';
      final result = parseConceptMarkers(input);

      expect(result.strippedText, 'Learn about spaced repetition today.');
      expect(result.markers, hasLength(1));
      expect(result.markers[0].conceptId, 'spaced-rep');
      // "Learn about " = 12 chars → startChar = 12
      expect(result.markers[0].startChar, 12);
      // "spaced repetition" = 17 chars → endChar = 29
      expect(result.markers[0].endChar, 29);
    });

    test('extracts multiple concept markers', () {
      const input =
          '[CONCEPT:a]Alpha[/CONCEPT] connects to [CONCEPT:b]Beta[/CONCEPT].';
      final result = parseConceptMarkers(input);

      expect(result.strippedText, 'Alpha connects to Beta.');
      expect(result.markers, hasLength(2));

      expect(result.markers[0].conceptId, 'a');
      expect(result.markers[0].startChar, 0);
      expect(result.markers[0].endChar, 5); // "Alpha"

      expect(result.markers[1].conceptId, 'b');
      expect(result.markers[1].startChar, 18); // "Alpha connects to " = 18
      expect(result.markers[1].endChar, 22); // "Beta" = 4 chars
    });

    test('returns unchanged text when no markers present', () {
      const input = 'Plain text with no markers at all.';
      final result = parseConceptMarkers(input);

      expect(result.strippedText, input);
      expect(result.markers, isEmpty);
    });

    test('handles hyphens and underscores in concept IDs', () {
      const input =
          '[CONCEPT:neural-network_v2]neural networks[/CONCEPT] are powerful.';
      final result = parseConceptMarkers(input);

      expect(result.strippedText, 'neural networks are powerful.');
      expect(result.markers, hasLength(1));
      expect(result.markers[0].conceptId, 'neural-network_v2');
    });

    test('skips unmatched opening tag gracefully', () {
      const input = 'This has [CONCEPT:orphan]no closing tag.';
      final result = parseConceptMarkers(input);

      // Unmatched tags are stripped but produce no marker.
      expect(result.markers, isEmpty);
      // The stripped text should remove the opening tag.
      expect(result.strippedText, contains('no closing tag'));
    });

    test('skips unmatched closing tag gracefully', () {
      const input = 'This has no opening[/CONCEPT] tag.';
      final result = parseConceptMarkers(input);

      expect(result.markers, isEmpty);
      // Orphan closing tag is stripped.
      expect(result.strippedText, contains('This has no opening'));
    });

    test('handles adjacent markers with no gap', () {
      const input = '[CONCEPT:a]Alpha[/CONCEPT][CONCEPT:b]Beta[/CONCEPT]';
      final result = parseConceptMarkers(input);

      expect(result.strippedText, 'AlphaBeta');
      expect(result.markers, hasLength(2));
      expect(
        result.markers[0],
        const ConceptMarker(conceptId: 'a', startChar: 0, endChar: 5),
      );
      expect(
        result.markers[1],
        const ConceptMarker(conceptId: 'b', startChar: 5, endChar: 9),
      );
    });

    test('handles empty concept content', () {
      const input = 'Before [CONCEPT:empty][/CONCEPT] after.';
      final result = parseConceptMarkers(input);

      expect(result.strippedText, 'Before  after.');
      expect(result.markers, hasLength(1));
      expect(result.markers[0].startChar, result.markers[0].endChar);
    });

    test('strips inner tags when markers are nested', () {
      // Nesting is not supported — the outer marker captures to the first
      // [/CONCEPT], and the inner [CONCEPT:B] tag is stripped as an orphan.
      const input = '[CONCEPT:A]Outer [CONCEPT:B]Inner[/CONCEPT] End[/CONCEPT]';
      final result = parseConceptMarkers(input);

      // The inner [CONCEPT:B] tag should be stripped from the content.
      expect(result.strippedText, contains('Outer Inner'));
      expect(result.strippedText, isNot(contains('[CONCEPT')));
      expect(result.strippedText, isNot(contains('[/CONCEPT')));
    });

    test('preserves multi-sentence content inside markers', () {
      const input =
          '[CONCEPT:long]This is a longer explanation. It has two sentences.[/CONCEPT]';
      final result = parseConceptMarkers(input);

      expect(
        result.strippedText,
        'This is a longer explanation. It has two sentences.',
      );
      expect(result.markers[0].startChar, 0);
      expect(result.markers[0].endChar, 51);
    });
  });
}
