import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'ingest_document.dart';
import 'topic.dart';

enum IngestPhase {
  idle,
  loadingCollections,
  ready,
  topicSelection,
  configuringTopic,
  ingesting,
  done,
  error,
}

@immutable
class IngestState {
  IngestState({
    this.phase = IngestPhase.idle,
    List<Map<String, dynamic>> collections = const [],
    this.selectedCollection,
    this.totalDocuments = 0,
    this.processedDocuments = 0,
    this.extractedCount = 0,
    this.skippedCount = 0,
    this.currentDocumentTitle = '',
    this.statusMessage = '',
    this.errorMessage = '',
    Set<String> sessionConceptIds = const {},
    this.selectedTopic,
    List<IngestDocument> availableDocuments = const [],
    Set<String> selectedDocumentIds = const {},
    this.topicName = '',
    this.topicDescription = '',
  })  : collections = IList(collections),
        sessionConceptIds = ISet(sessionConceptIds),
        availableDocuments = IList(availableDocuments),
        selectedDocumentIds = ISet(selectedDocumentIds);

  const IngestState._({
    this.phase = IngestPhase.idle,
    this.collections = const IListConst([]),
    this.selectedCollection,
    this.totalDocuments = 0,
    this.processedDocuments = 0,
    this.extractedCount = 0,
    this.skippedCount = 0,
    this.currentDocumentTitle = '',
    this.statusMessage = '',
    this.errorMessage = '',
    this.sessionConceptIds = const ISetConst({}),
    this.selectedTopic,
    this.availableDocuments = const IListConst([]),
    this.selectedDocumentIds = const ISetConst({}),
    this.topicName = '',
    this.topicDescription = '',
  });

  static const empty = IngestState._();

  final IngestPhase phase;
  final IList<Map<String, dynamic>> collections;
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
  final ISet<String> sessionConceptIds;

  /// The topic being configured or ingested.
  final Topic? selectedTopic;

  /// Documents available for selection, with status info.
  final IList<IngestDocument> availableDocuments;

  /// User's document selection for the current ingestion run.
  final ISet<String> selectedDocumentIds;

  /// Name for a new topic being created.
  final String topicName;

  /// Description for a new topic being created.
  final String topicDescription;

  double get progress =>
      totalDocuments > 0 ? processedDocuments / totalDocuments : 0;

  IngestState copyWith({
    IngestPhase? phase,
    IList<Map<String, dynamic>>? collections,
    Map<String, dynamic>? Function()? selectedCollection,
    int? totalDocuments,
    int? processedDocuments,
    int? extractedCount,
    int? skippedCount,
    String? currentDocumentTitle,
    String? statusMessage,
    String? errorMessage,
    ISet<String>? sessionConceptIds,
    Topic? Function()? selectedTopic,
    IList<IngestDocument>? availableDocuments,
    ISet<String>? selectedDocumentIds,
    String? topicName,
    String? topicDescription,
  }) {
    return IngestState._(
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
      selectedTopic:
          selectedTopic != null ? selectedTopic() : this.selectedTopic,
      availableDocuments: availableDocuments ?? this.availableDocuments,
      selectedDocumentIds: selectedDocumentIds ?? this.selectedDocumentIds,
      topicName: topicName ?? this.topicName,
      topicDescription: topicDescription ?? this.topicDescription,
    );
  }
}
