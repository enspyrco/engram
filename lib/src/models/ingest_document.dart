import 'package:meta/meta.dart';

/// Status of a document relative to the current knowledge graph.
enum IngestDocumentStatus { newDoc, changed, unchanged }

/// A document available for topic-based ingestion, with metadata about its
/// current state relative to the knowledge graph.
@immutable
class IngestDocument {
  const IngestDocument({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.collectionId,
    required this.collectionName,
    required this.status,
  });

  final String id;
  final String title;
  final String updatedAt;
  final String collectionId;
  final String collectionName;
  final IngestDocumentStatus status;

  String get statusLabel => switch (status) {
        IngestDocumentStatus.newDoc => 'new',
        IngestDocumentStatus.changed => 'changed',
        IngestDocumentStatus.unchanged => 'unchanged',
      };
}
