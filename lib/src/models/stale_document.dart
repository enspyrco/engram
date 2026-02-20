import 'package:meta/meta.dart';

/// A document whose wiki content has changed since last ingestion.
@immutable
class StaleDocument {
  const StaleDocument({
    required this.id,
    required this.title,
    this.ingestedAt,
  });

  /// The Outline document ID.
  final String id;

  /// The document title.
  final String title;

  /// When the document was last ingested, or `null` if it has never been
  /// ingested (i.e. it is a new document).
  final String? ingestedAt;

  /// Whether this document has been previously ingested and therefore can
  /// show a diff.
  bool get hasBeenIngested => ingestedAt != null;
}
