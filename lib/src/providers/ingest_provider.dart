import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingest_state.dart';
import 'graph_store_provider.dart';
import 'knowledge_graph_provider.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

final ingestProvider =
    NotifierProvider<IngestNotifier, IngestState>(IngestNotifier.new);

class IngestNotifier extends Notifier<IngestState> {
  @override
  IngestState build() => IngestState.empty;

  Future<void> loadCollections() async {
    state = state.copyWith(phase: IngestPhase.loadingCollections);
    try {
      final client = ref.read(outlineClientProvider);
      final collections = await client.listCollections();
      state = state.copyWith(
        phase: IngestPhase.ready,
        collections: IList(collections),
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

  Future<void> startIngestion({bool forceReExtract = false}) async {
    final collection = state.selectedCollection;
    if (collection == null) return;

    state = state.copyWith(
      phase: IngestPhase.ingesting,
      extractedCount: 0,
      skippedCount: 0,
      processedDocuments: 0,
      sessionConceptIds: const ISetConst({}),
    );

    try {
      final client = ref.read(outlineClientProvider);
      final extraction = ref.read(extractionServiceProvider);
      final graphNotifier = ref.read(knowledgeGraphProvider.notifier);

      final collectionId = collection['id'] as String;
      final collectionName = collection['name'] as String?;
      state = state.copyWith(statusMessage: 'Listing documents...');
      debugPrint('[Ingest] Listing documents for collection $collectionId');
      final documents = await client.listDocuments(collectionId);
      debugPrint('[Ingest] Found ${documents.length} documents');

      state = state.copyWith(
        totalDocuments: documents.length,
        statusMessage: 'Loading existing graph...',
      );

      debugPrint('[Ingest] Loading existing graph from storage...');
      final initialGraph = await ref.read(knowledgeGraphProvider.future)
          .timeout(const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                  'Loading graph from storage timed out after 30s'));
      debugPrint('[Ingest] Graph loaded: '
          '${initialGraph.concepts.length} concepts, '
          '${initialGraph.quizItems.length} quiz items');

      var graph = initialGraph;
      var extracted = 0;
      var skipped = 0;

      for (final doc in documents) {
        final docId = doc['id'] as String;
        final docTitle = doc['title'] as String;
        final updatedAt = doc['updatedAt'] as String;

        state = state.copyWith(currentDocumentTitle: docTitle);

        // Skip unchanged documents (unless force re-extract is enabled)
        final existing = graph.documentMetadata
            .where((m) => m.documentId == docId)
            .firstOrNull;
        if (!forceReExtract &&
            existing != null &&
            existing.updatedAt == updatedAt) {
          // Collect documents that need collection info backfill — we'll
          // batch-save after the loop to avoid N separate Firestore writes.
          if (existing.collectionId == null) {
            graphNotifier.backfillCollectionInfo(
              docId,
              collectionId: collectionId,
              collectionName: collectionName ?? '',
              skipPersist: true,
            );
          }
          debugPrint('[Ingest] Skipping "$docTitle" (unchanged)');
          skipped++;
          state = state.copyWith(
            processedDocuments: extracted + skipped,
            skippedCount: skipped,
            statusMessage: 'Skipped (unchanged)',
          );
          continue;
        }

        // Fetch full document
        state = state.copyWith(statusMessage: 'Fetching from Outline...');
        debugPrint('[Ingest] Fetching "$docTitle" from Outline...');
        final fullDoc = await client.getDocument(docId);
        final content = fullDoc['text'] as String? ?? '';
        debugPrint('[Ingest] Got ${content.length} chars for "$docTitle"');

        if (content.trim().isEmpty) {
          debugPrint('[Ingest] Skipping "$docTitle" (empty content)');
          skipped++;
          state = state.copyWith(
            processedDocuments: extracted + skipped,
            skippedCount: skipped,
            statusMessage: 'Skipped (empty document)',
          );
          continue;
        }

        // Extract knowledge via Claude API
        state = state.copyWith(
          statusMessage: 'Extracting knowledge (${content.length} chars)...',
        );
        debugPrint('[Ingest] Extracting knowledge from "$docTitle" '
            '(${content.length} chars)...');
        final stopwatch = Stopwatch()..start();
        final result = await extraction.extract(
          documentTitle: docTitle,
          documentContent: content,
          existingConceptIds: graph.concepts.map((c) => c.id).toList(),
        ).timeout(const Duration(minutes: 3),
            onTimeout: () => throw TimeoutException(
                'Claude extraction timed out after 3 min for "$docTitle"'));
        debugPrint('[Ingest] Extraction complete in ${stopwatch.elapsed}: '
            '${result.concepts.length} concepts, '
            '${result.relationships.length} relationships, '
            '${result.quizItems.length} quiz items');

        // Merge into graph — staggered for live knowledge graph animation.
        // Register session concept IDs first so the live graph filter can
        // show nodes as they appear during staggered ingestion.
        state = state.copyWith(
          statusMessage: 'Adding ${result.concepts.length} concepts...',
          sessionConceptIds: state.sessionConceptIds
              .addAll(result.concepts.map((c) => c.id)),
        );
        debugPrint('[Ingest] Adding concepts to graph...');
        try {
          await graphNotifier.staggeredIngestExtraction(
            result,
            documentId: docId,
            documentTitle: docTitle,
            updatedAt: updatedAt,
            collectionId: collectionId,
            collectionName: collectionName,
          ).timeout(const Duration(minutes: 2),
              onTimeout: () => throw TimeoutException(
                  'Staggered ingestion timed out after 2 min'));
          debugPrint('[Ingest] Saved successfully');
        } on TimeoutException {
          debugPrint('[Ingest] Storage save timed out — '
              'data is in memory, will retry on next save');
          state = state.copyWith(
            statusMessage: 'Save timed out (data kept in memory)',
          );
        }

        graph = ref.read(knowledgeGraphProvider).valueOrNull ?? graph;
        extracted++;
        state = state.copyWith(
          processedDocuments: extracted + skipped,
          extractedCount: extracted,
          statusMessage: '${result.concepts.length} concepts extracted',
        );
      }

      // Batch-persist any backfilled collection info (single save instead
      // of N individual writes).
      final currentGraph = ref.read(knowledgeGraphProvider).valueOrNull;
      if (currentGraph != null && skipped > 0) {
        final repo = ref.read(graphRepositoryProvider);
        unawaited(repo.save(currentGraph).catchError((e) {
          debugPrint('[Ingest] Backfill batch save failed: $e');
        }));
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
    state = IngestState.empty;
  }
}
