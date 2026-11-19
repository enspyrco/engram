import 'dart:math' as math;

import '../models/narration_script.dart';
import '../models/timestamped_concept.dart';

/// Maps character-offset [ConceptMarker]s to time-aligned
/// [TimestampedConcept]s using ElevenLabs character-level timing data.
///
/// The [characterStartTimes] and [characterEndTimes] arrays are parallel
/// lists where index `i` gives the start/end time (in seconds) for the
/// `i`-th character of the stripped TTS text.
///
/// Performs defensive bounds checking:
/// - If timing arrays are empty, returns an empty list.
/// - Character offsets are clamped to `[0, length - 1]`.
List<TimestampedConcept> mapMarkersToTimestamps({
  required List<ConceptMarker> markers,
  required List<double> characterStartTimes,
  required List<double> characterEndTimes,
}) {
  if (characterStartTimes.isEmpty || characterEndTimes.isEmpty) {
    return const [];
  }

  final maxIndex =
      math.min(characterStartTimes.length, characterEndTimes.length) - 1;

  return [
    for (final marker in markers)
      _mapSingleMarker(
        marker,
        characterStartTimes,
        characterEndTimes,
        maxIndex,
      ),
  ];
}

TimestampedConcept _mapSingleMarker(
  ConceptMarker marker,
  List<double> startTimes,
  List<double> endTimes,
  int maxIndex,
) {
  final int clampedStart = marker.startChar.clamp(0, maxIndex);

  // endChar is exclusive in ConceptMarker, so the last included character
  // is at endChar - 1. For zero-width markers (start == end), use start.
  final lastIncluded =
      marker.endChar > marker.startChar ? marker.endChar - 1 : marker.startChar;
  final int clampedEnd = lastIncluded.clamp(
    0,
    math.min(maxIndex, endTimes.length - 1),
  );

  return TimestampedConcept(
    conceptId: marker.conceptId,
    startTime: startTimes[clampedStart],
    endTime: endTimes[clampedEnd],
  );
}
