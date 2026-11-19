import '../models/narration_script.dart';

/// Regex matching `[CONCEPT:id]content[/CONCEPT]` pairs.
///
/// Concept IDs may contain alphanumerics, hyphens, and underscores.
/// Uses a non-greedy `.*?` for the inner content so adjacent markers parse
/// correctly. Nesting is **not supported** — if tags are nested, the inner
/// tags are stripped from the matched content as orphans.
final _markerPattern = RegExp(
  r'\[CONCEPT:([\w-]+)\](.*?)\[/CONCEPT\]',
  dotAll: true,
);

/// Regex matching orphan opening tags (no matching close).
final _orphanOpenPattern = RegExp(r'\[CONCEPT:[\w-]+\]');

/// Regex matching orphan closing tags (no matching open).
final _orphanClosePattern = RegExp(r'\[/CONCEPT\]');

/// Parses `[CONCEPT:id]...[/CONCEPT]` markers from an annotated script.
///
/// Concept IDs must match `[a-zA-Z0-9_-]+`. IDs containing colons, spaces, or
/// other characters are silently ignored (the tag is stripped as an orphan).
///
/// Returns a [MarkerParseResult] containing:
/// - [MarkerParseResult.strippedText]: the narration text with all tags
///   removed, suitable for TTS synthesis.
/// - [MarkerParseResult.markers]: character-offset markers mapped to the
///   stripped text.
///
/// Unmatched opening or closing tags are silently stripped with no marker
/// produced, ensuring the TTS text is always clean.
MarkerParseResult parseConceptMarkers(String annotatedText) {
  final markers = <ConceptMarker>[];
  final buffer = StringBuffer();

  var lastEnd = 0;

  for (final match in _markerPattern.allMatches(annotatedText)) {
    // Append text between previous match and this one, cleaning orphans.
    final between = annotatedText.substring(lastEnd, match.start);
    buffer.write(_stripOrphanTags(between));

    final conceptId = match.group(1)!;
    final content = match.group(2)!;

    // Strip any orphan tags that ended up inside the match content (e.g., from
    // nested markers like [A]...[B]...[/B]...[/A] where the non-greedy regex
    // captures the inner [B] tag as part of A's content).
    final cleanContent = _stripOrphanTags(content);

    final startChar = buffer.length;
    buffer.write(cleanContent);
    final endChar = buffer.length;

    markers.add(
      ConceptMarker(
        conceptId: conceptId,
        startChar: startChar,
        endChar: endChar,
      ),
    );

    lastEnd = match.end;
  }

  // Append any trailing text after the last match.
  final trailing = annotatedText.substring(lastEnd);
  buffer.write(_stripOrphanTags(trailing));

  return MarkerParseResult(strippedText: buffer.toString(), markers: markers);
}

/// Remove orphan opening/closing tags that weren't part of a matched pair.
String _stripOrphanTags(String text) {
  return text
      .replaceAll(_orphanOpenPattern, '')
      .replaceAll(_orphanClosePattern, '');
}
