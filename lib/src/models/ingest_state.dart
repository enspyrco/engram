import 'package:meta/meta.dart';

enum IngestPhase { idle, loadingCollections, ready, ingesting, done, error }

@immutable
class IngestState {
  const IngestState({
    this.phase = IngestPhase.idle,
    this.collections = const [],
    this.selectedCollection,
    this.totalDocuments = 0,
    this.processedDocuments = 0,
    this.extractedCount = 0,
    this.skippedCount = 0,
    this.currentDocumentTitle = '',
    this.statusMessage = '',
    this.errorMessage = '',
    this.sessionConceptIds = const {},
  });

  final IngestPhase phase;
  final List<Map<String, dynamic>> collections;
  final Map<String, dynamic>? selectedCollection;
  final int totalDocuments;
  final int processedDocuments;
  final int extractedCount;
  final int skippedCount;
  final String currentDocumentTitle;
  final String statusMessage;
  final String errorMessage;

  /// Concept IDs extracted during this ingestion session. Used to filter the
  /// live graph visualization to only show newly extracted nodes.
  final Set<String> sessionConceptIds;

  double get progress =>
      totalDocuments > 0 ? processedDocuments / totalDocuments : 0;

  IngestState copyWith({
    IngestPhase? phase,
    List<Map<String, dynamic>>? collections,
    Map<String, dynamic>? Function()? selectedCollection,
    int? totalDocuments,
    int? processedDocuments,
    int? extractedCount,
    int? skippedCount,
    String? currentDocumentTitle,
    String? statusMessage,
    String? errorMessage,
    Set<String>? sessionConceptIds,
  }) {
    return IngestState(
      phase: phase ?? this.phase,
      collections: collections ?? this.collections,
      selectedCollection: selectedCollection != null
          ? selectedCollection()
          : this.selectedCollection,
      totalDocuments: totalDocuments ?? this.totalDocuments,
      processedDocuments: processedDocuments ?? this.processedDocuments,
      extractedCount: extractedCount ?? this.extractedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      currentDocumentTitle: currentDocumentTitle ?? this.currentDocumentTitle,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      sessionConceptIds: sessionConceptIds ?? this.sessionConceptIds,
    );
  }
}
