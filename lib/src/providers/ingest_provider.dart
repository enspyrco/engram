import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingest_state.dart';
import 'knowledge_graph_provider.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

final ingestProvider =
    NotifierProvider<IngestNotifier, IngestState>(IngestNotifier.new);

class IngestNotifier extends Notifier<IngestState> {
  @override
  IngestState build() => const IngestState();

  Future<void> loadCollections() async {
    state = state.copyWith(phase: IngestPhase.loadingCollections);
    try {
      final client = ref.read(outlineClientProvider);
      final collections = await client.listCollections();
      state = state.copyWith(
        phase: IngestPhase.ready,
        collections: collections,
      );
    } catch (e) {
      state = state.copyWith(
        phase: IngestPhase.error,
        errorMessage: 'Failed to load collections: $e',
      );
    }
  }

  void selectCollection(Map<String, dynamic> collection) {
    state = state.copyWith(
      selectedCollection: () => collection,
    );
  }

  Future<void> startIngestion() async {
    final collection = state.selectedCollection;
    if (collection == null) return;

    state = state.copyWith(
      phase: IngestPhase.ingesting,
      extractedCount: 0,
      skippedCount: 0,
      processedDocuments: 0,
    );

    try {
      final client = ref.read(outlineClientProvider);
      final extraction = ref.read(extractionServiceProvider);
      final graphNotifier = ref.read(knowledgeGraphProvider.notifier);

      final collectionId = collection['id'] as String;
      final documents = await client.listDocuments(collectionId);

      state = state.copyWith(totalDocuments: documents.length);

      final initialGraph = ref.read(knowledgeGraphProvider).valueOrNull;
      if (initialGraph == null) return;

      var graph = initialGraph;
      var extracted = 0;
      var skipped = 0;

      for (final doc in documents) {
        final docId = doc['id'] as String;
        final docTitle = doc['title'] as String;
        final updatedAt = doc['updatedAt'] as String;

        state = state.copyWith(currentDocumentTitle: docTitle);

        // Skip unchanged documents
        final existing = graph.documentMetadata
            .where((m) => m.documentId == docId)
            .firstOrNull;
        if (existing != null && existing.updatedAt == updatedAt) {
          skipped++;
          state = state.copyWith(
            processedDocuments: extracted + skipped,
            skippedCount: skipped,
          );
          continue;
        }

        // Fetch full document
        final fullDoc = await client.getDocument(docId);
        final content = fullDoc['text'] as String? ?? '';

        if (content.trim().isEmpty) {
          skipped++;
          state = state.copyWith(
            processedDocuments: extracted + skipped,
            skippedCount: skipped,
          );
          continue;
        }

        // Extract knowledge
        final result = await extraction.extract(
          documentTitle: docTitle,
          documentContent: content,
          existingConceptIds: graph.concepts.map((c) => c.id).toList(),
        );

        // Merge into graph
        await graphNotifier.ingestExtraction(
          result,
          documentId: docId,
          documentTitle: docTitle,
          updatedAt: updatedAt,
        );

        graph = ref.read(knowledgeGraphProvider).valueOrNull ?? graph;
        extracted++;
        state = state.copyWith(
          processedDocuments: extracted + skipped,
          extractedCount: extracted,
        );
      }

      // Record the collection ID for sync checks
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.addIngestedCollectionId(collectionId);

      state = state.copyWith(
        phase: IngestPhase.done,
        currentDocumentTitle: '',
      );
    } catch (e) {
      state = state.copyWith(
        phase: IngestPhase.error,
        errorMessage: 'Ingestion failed: $e',
      );
    }
  }

  void reset() {
    state = const IngestState();
  }
}
