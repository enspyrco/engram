import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ingest_document.dart';
import '../models/ingest_state.dart';
import '../models/topic.dart';
import 'clock_provider.dart';
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
        phase: IngestPhase.topicSelection,
        collections: IList(collections),
      );
    } catch (e) {
      // Show topic selection even when offline — existing topics are local.
      // New topic creation will be limited (no document list), but users
      // can still browse and re-ingest existing topics.
      final hasTopics = ref
              .read(knowledgeGraphProvider)
              .valueOrNull
              ?.topics
              .isNotEmpty ??
          false;
      if (hasTopics) {
        state = state.copyWith(
          phase: IngestPhase.topicSelection,
          statusMessage: 'Offline — showing saved topics',
        );
      } else {
        state = state.copyWith(
          phase: IngestPhase.error,
          errorMessage: 'Failed to load collections: $e',
        );
      }
    }
  }

  void selectCollection(Map<String, dynamic> collection) {
    state = state.copyWith(
      selectedCollection: () => collection,
    );
  }

  /// Begin configuring a new topic.
  void startNewTopic() {
    state = state.copyWith(
      phase: IngestPhase.configuringTopic,
      selectedTopic: () => null,
      topicName: '',
      topicDescription: '',
      availableDocuments: const IListConst([]),
      selectedDocumentIds: const ISetConst({}),
    );
  }

  /// Begin configuring an existing topic for re-ingestion.
  void selectTopic(Topic topic) {
    state = state.copyWith(
      phase: IngestPhase.configuringTopic,
      selectedTopic: () => topic,
      topicName: topic.name,
      topicDescription: topic.description ?? '',
      selectedDocumentIds: topic.documentIds,
    );
  }

  void updateTopicName(String name) {
    state = state.copyWith(topicName: name);
  }

  void updateTopicDescription(String description) {
    state = state.copyWith(topicDescription: description);
  }

  /// Load documents from all available collections and compute their status
  /// (new/changed/unchanged) relative to the current knowledge graph.
  Future<void> loadDocumentsForAllCollections() async {
    state = state.copyWith(statusMessage: 'Loading documents...');
    try {
      final client = ref.read(outlineClientProvider);
      final graph =
          ref.read(knowledgeGraphProvider).valueOrNull;

      final allDocs = <IngestDocument>[];
      for (final collection in state.collections) {
        final collectionId = collection['id'] as String;
        final collectionName = collection['name'] as String? ?? 'Untitled';
        final docs = await client.listDocuments(collectionId);
        for (final doc in docs) {
          final docId = doc['id'] as String;
          final updatedAt = doc['updatedAt'] as String;

          // Compute status
          var docStatus = IngestDocumentStatus.newDoc;
          if (graph != null) {
            final meta = graph.documentMetadata
                .where((m) => m.documentId == docId)
                .firstOrNull;
            if (meta != null) {
              docStatus = meta.updatedAt == updatedAt
                  ? IngestDocumentStatus.unchanged
                  : IngestDocumentStatus.changed;
            }
          }

          allDocs.add(IngestDocument(
            id: docId,
            title: doc['title'] as String,
            updatedAt: updatedAt,
            collectionId: collectionId,
            collectionName: collectionName,
            status: docStatus,
          ));
        }
      }

      state = state.copyWith(
        availableDocuments: IList(allDocs),
        statusMessage: '',
      );
    } catch (e) {
      state = state.copyWith(
        statusMessage: 'Failed to load documents: $e',
      );
    }
  }

  /// Toggle a document's selection state.
  void toggleDocument(String documentId) {
    final current = state.selectedDocumentIds;
    final updated = current.contains(documentId)
        ? current.remove(documentId)
        : current.add(documentId);
    state = state.copyWith(selectedDocumentIds: updated);
  }

  /// Select all documents in a collection.
  void selectAllInCollection(String collectionId) {
    final docIds = state.availableDocuments
        .where((d) => d.collectionId == collectionId)
        .map((d) => d.id);
    state = state.copyWith(
      selectedDocumentIds: state.selectedDocumentIds.addAll(docIds),
    );
  }

  /// Deselect all documents in a collection.
  void deselectAllInCollection(String collectionId) {
    final docIds = state.availableDocuments
        .where((d) => d.collectionId == collectionId)
        .map((d) => d.id)
        .toSet();
    state = state.copyWith(
      selectedDocumentIds: state.selectedDocumentIds.removeAll(docIds),
    );
  }

  /// Start topic-aware ingestion for selected documents.
  Future<void> startTopicIngestion({bool forceReExtract = false}) async {
    if (state.selectedDocumentIds.isEmpty) return;

    // Create or update the topic
    final graphNotifier = ref.read(knowledgeGraphProvider.notifier);
    final now = ref.read(clockProvider)();
    final isNewTopic = state.selectedTopic == null;

    final topic = isNewTopic
        ? Topic(
            id: const Uuid().v4(),
            name: state.topicName.isNotEmpty
                ? state.topicName
                : 'Topic ${now.toIso8601String()}',
            description:
                state.topicDescription.isNotEmpty ? state.topicDescription : null,
            documentIds: state.selectedDocumentIds.unlock,
            createdAt: now.toIso8601String(),
          )
        : state.selectedTopic!.copyWith(
            name: state.topicName.isNotEmpty
                ? state.topicName
                : state.selectedTopic!.name,
            description: () => state.topicDescription.isNotEmpty
                ? state.topicDescription
                : state.selectedTopic!.description,
            documentIds: state.selectedDocumentIds,
          );

    state = state.copyWith(
      phase: IngestPhase.ingesting,
      selectedTopic: () => topic,
      extractedCount: 0,
      skippedCount: 0,
      processedDocuments: 0,
      sessionConceptIds: const ISetConst({}),
    );

    try {
      final client = ref.read(outlineClientProvider);
      final extraction = ref.read(extractionServiceProvider);

      // Build the list of documents to process from the selected IDs
      final docsToProcess = state.availableDocuments
          .where((d) => state.selectedDocumentIds.contains(d.id))
          .toList();

      state = state.copyWith(totalDocuments: docsToProcess.length);

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

      for (final doc in docsToProcess) {
        final docId = doc.id;
        final docTitle = doc.title;
        final updatedAt = doc.updatedAt;
        final collectionId = doc.collectionId;
        final collectionName = doc.collectionName;

        state = state.copyWith(currentDocumentTitle: docTitle);

        // Skip unchanged documents (unless force re-extract is enabled)
        final existing = graph.documentMetadata
            .where((m) => m.documentId == docId)
            .firstOrNull;
        if (!forceReExtract &&
            existing != null &&
            existing.updatedAt == updatedAt) {
          if (existing.collectionId == null) {
            graphNotifier.backfillCollectionInfo(
              docId,
              collectionId: collectionId,
              collectionName: collectionName,
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

        // Extract knowledge via Claude API — pass ALL existing concept IDs
        // (full graph, not just topic) so Claude can create cross-document
        // relationships.
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

        // Merge into graph with staggered animation
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
            documentText: content,
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

      // Batch-persist any backfilled collection info
      final currentGraph = ref.read(knowledgeGraphProvider).valueOrNull;
      if (currentGraph != null && skipped > 0) {
        final repo = ref.read(graphRepositoryProvider);
        unawaited(repo.save(currentGraph).catchError((e) {
          debugPrint('[Ingest] Backfill batch save failed: $e');
        }));
      }

      // Save the topic to the graph
      final finishedTopic = topic.withLastIngestedAt(
        ref.read(clockProvider)().toIso8601String(),
      );
      graphNotifier.upsertTopic(finishedTopic);

      // Record collection IDs for sync checks
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final collectionIds = docsToProcess
          .map((d) => d.collectionId)
          .toSet();
      for (final cid in collectionIds) {
        await settingsRepo.addIngestedCollectionId(cid);
      }

      state = state.copyWith(
        phase: IngestPhase.done,
        currentDocumentTitle: '',
        selectedTopic: () => finishedTopic,
      );
    } catch (e) {
      state = state.copyWith(
        phase: IngestPhase.error,
        errorMessage: 'Ingestion failed: $e',
      );
    }
  }

  /// Legacy single-collection ingestion (kept for backward compatibility).
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
            documentText: content,
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
