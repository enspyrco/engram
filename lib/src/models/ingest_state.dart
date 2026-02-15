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
    );
  }
}
