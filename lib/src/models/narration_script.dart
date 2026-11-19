import 'package:meta/meta.dart';

/// A concept marker found in an annotated narration script.
///
/// Represents the character-offset range where a concept is mentioned in the
/// stripped (tag-free) text. Produced by [parseConceptMarkers] and consumed by
/// [mapMarkersToTimestamps] to create time-aligned concept highlights.
@immutable
class ConceptMarker {
  const ConceptMarker({
    required this.conceptId,
    required this.startChar,
    required this.endChar,
  });

  /// The concept this marker refers to.
  final String conceptId;

  /// Inclusive start offset in the stripped text.
  final int startChar;

  /// Exclusive end offset in the stripped text.
  final int endChar;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConceptMarker &&
          other.conceptId == conceptId &&
          other.startChar == startChar &&
          other.endChar == endChar;

  @override
  int get hashCode => Object.hash(conceptId, startChar, endChar);

  @override
  String toString() => 'ConceptMarker($conceptId, chars $startChar–$endChar)';
}

/// Result of parsing concept markers from an annotated script.
@immutable
class MarkerParseResult {
  const MarkerParseResult({required this.strippedText, required this.markers});

  /// The narration text with all `[CONCEPT:...]...[/CONCEPT]` tags removed.
  final String strippedText;

  /// Concept markers with character offsets into [strippedText].
  final List<ConceptMarker> markers;
}
