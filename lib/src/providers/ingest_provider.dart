import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/concept.dart';
import '../models/ingest_document.dart';
import '../models/ingest_state.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import '../models/topic.dart';
import '../services/extraction_service.dart';
import 'clock_provider.dart';
import 'difficulty_evaluation_provider.dart';
import 'knowledge_graph_provider.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

final ingestProvider = NotifierProvider<IngestNotifier, IngestState>(
  IngestNotifier.new,
);

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
      final hasTopics =
          ref.read(knowledgeGraphProvider).valueOrNull?.topics.isNotEmpty ??
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
    state = state.copyWith(selectedCollection: () => collection);
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
      final graph = ref.read(knowledgeGraphProvider).valueOrNull;

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
            final meta =
                graph.documentMetadata
                    .where((m) => m.documentId == docId)
                    .firstOrNull;
            if (meta != null) {
              docStatus =
                  meta.updatedAt == updatedAt
                      ? IngestDocumentStatus.unchanged
                      : IngestDocumentStatus.changed;
            }
          }

          allDocs.add(
            IngestDocument(
              id: docId,
              title: doc['title'] as String,
              updatedAt: updatedAt,
              collectionId: collectionId,
              collectionName: collectionName,
              status: docStatus,
            ),
          );
        }
      }

      state = state.copyWith(
        availableDocuments: IList(allDocs),
        statusMessage: '',
      );
    } catch (e) {
      state = state.copyWith(statusMessage: 'Failed to load documents: $e');
    }
  }

  /// Toggle a document's selection state.
  void toggleDocument(String documentId) {
    final current = state.selectedDocumentIds;
    final updated =
        current.contains(documentId)
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
    final docIds =
        state.availableDocuments
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

    final topic =
        isNewTopic
            ? Topic(
              id: const Uuid().v4(),
              name:
                  state.topicName.isNotEmpty
                      ? state.topicName
                      : 'Topic ${now.toIso8601String()}',
              description:
                  state.topicDescription.isNotEmpty
                      ? state.topicDescription
                      : null,
              documentIds: state.selectedDocumentIds.unlock,
              createdAt: now,
            )
            : state.selectedTopic!.copyWith(
              name:
                  state.topicName.isNotEmpty
                      ? state.topicName
                      : state.selectedTopic!.name,
              description:
                  () =>
                      state.topicDescription.isNotEmpty
                          ? state.topicDescription
                          : state.selectedTopic!.description,
              documentIds: state.selectedDocumentIds,
            );

    // Persist the user's edit now, diffed against the copy they edited
    // from, so a link another device adds during the ingest is not undone.
    final editedFrom = state.selectedTopic;
    await ref.read(knowledgeGraphProvider.future);
    graphNotifier.upsertTopic(topic, previous: editedFrom);

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
      final predictionAccuracy = ref.read(difficultyEvaluationProvider);

      // Build the list of documents to process from the selected IDs
      final docsToProcess =
          state.availableDocuments
              .where((d) => state.selectedDocumentIds.contains(d.id))
              .toList();

      state = state.copyWith(totalDocuments: docsToProcess.length);

      debugPrint('[Ingest] Loading existing graph from storage...');
      final initialGraph = await ref
          .read(knowledgeGraphProvider.future)
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () =>
                    throw TimeoutException(
                      'Loading graph from storage timed out after 30s',
                    ),
          );
      debugPrint(
        '[Ingest] Graph loaded: '
        '${initialGraph.concepts.length} concepts, '
        '${initialGraph.quizItems.length} quiz items',
      );

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
        final existing =
            graph.documentMetadata
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
        // relationships. Include prediction accuracy for calibration feedback.
        state = state.copyWith(
          statusMessage: 'Extracting knowledge (${content.length} chars)...',
        );
        debugPrint(
          '[Ingest] Extracting knowledge from "$docTitle" '
          '(${content.length} chars)...',
        );
        final stopwatch = Stopwatch()..start();
        final result = await extraction
            .extract(
              documentTitle: docTitle,
              documentContent: content,
              existingConceptIds: graph.concepts.map((c) => c.id).toList(),
              predictionAccuracy: predictionAccuracy,
            )
            .timeout(
              _extractionTimeout(content.length),
              onTimeout:
                  () =>
                      throw TimeoutException(
                        'Claude extraction timed out for "$docTitle"',
                      ),
            );
        debugPrint(
          '[Ingest] Extraction complete in ${stopwatch.elapsed}: '
          '${result.concepts.length} concepts, '
          '${result.relationships.length} relationships, '
          '${result.quizItems.length} quiz items '
          '(${result.quizItems.where((q) => q.rubric != null).length} '
          'with a rubric, ${result.rejectedRubricCount} rubrics rejected)',
        );

        // Auto-split high-difficulty items into sub-concepts
        final augmented = await _autoSplitHighDifficulty(
          result,
          extraction,
          docId,
        );

        // Merge into graph with staggered animation
        state = state.copyWith(
          statusMessage: 'Adding ${augmented.concepts.length} concepts...',
          sessionConceptIds: state.sessionConceptIds.addAll(
            augmented.concepts.map((c) => c.id),
          ),
        );
        debugPrint('[Ingest] Adding concepts to graph...');
        try {
          await graphNotifier
              .staggeredIngestExtraction(
                augmented,
                documentId: docId,
                documentTitle: docTitle,
                updatedAt: updatedAt,
                collectionId: collectionId,
                collectionName: collectionName,
                documentText: content,
              )
              .timeout(
                const Duration(minutes: 2),
                onTimeout:
                    () =>
                        throw TimeoutException(
                          'Staggered ingestion timed out after 2 min',
                        ),
              );
          debugPrint('[Ingest] Saved successfully');
        } on TimeoutException {
          // No later write picks an extraction up again. If it never
          // committed, its document row wasn't written either, so the next
          // ingest re-extracts it instead of skipping it as unchanged.
          debugPrint(
            '[Ingest] Ingest of "$docTitle" timed out; '
            're-run ingest if its concepts are missing',
          );
          state = state.copyWith(
            statusMessage:
                'Timed out; re-run ingest if this document is missing',
          );
        }

        graph = ref.read(knowledgeGraphProvider).valueOrNull ?? graph;
        extracted++;
        state = state.copyWith(
          processedDocuments: extracted + skipped,
          extractedCount: extracted,
          statusMessage: '${augmented.concepts.length} concepts extracted',
        );
      }

      graphNotifier.markTopicIngested(topic.id);
      final finishedTopic =
          ref
              .read(knowledgeGraphProvider)
              .valueOrNull
              ?.topics
              .where((t) => t.id == topic.id)
              .firstOrNull ??
          topic;

      // Record collection IDs for sync checks
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final collectionIds = docsToProcess.map((d) => d.collectionId).toSet();
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
      final predictionAccuracy = ref.read(difficultyEvaluationProvider);

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
      final initialGraph = await ref
          .read(knowledgeGraphProvider.future)
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () =>
                    throw TimeoutException(
                      'Loading graph from storage timed out after 30s',
                    ),
          );
      debugPrint(
        '[Ingest] Graph loaded: '
        '${initialGraph.concepts.length} concepts, '
        '${initialGraph.quizItems.length} quiz items',
      );

      var graph = initialGraph;
      var extracted = 0;
      var skipped = 0;

      for (final doc in documents) {
        final docId = doc['id'] as String;
        final docTitle = doc['title'] as String;
        final updatedAt = doc['updatedAt'] as String;

        state = state.copyWith(currentDocumentTitle: docTitle);

        // Skip unchanged documents (unless force re-extract is enabled)
        final existing =
            graph.documentMetadata
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

        // Extract knowledge via Claude API — include prediction accuracy
        // for calibration feedback.
        state = state.copyWith(
          statusMessage: 'Extracting knowledge (${content.length} chars)...',
        );
        debugPrint(
          '[Ingest] Extracting knowledge from "$docTitle" '
          '(${content.length} chars)...',
        );
        final stopwatch = Stopwatch()..start();
        final result = await extraction
            .extract(
              documentTitle: docTitle,
              documentContent: content,
              existingConceptIds: graph.concepts.map((c) => c.id).toList(),
              predictionAccuracy: predictionAccuracy,
            )
            .timeout(
              _extractionTimeout(content.length),
              onTimeout:
                  () =>
                      throw TimeoutException(
                        'Claude extraction timed out for "$docTitle"',
                      ),
            );
        debugPrint(
          '[Ingest] Extraction complete in ${stopwatch.elapsed}: '
          '${result.concepts.length} concepts, '
          '${result.relationships.length} relationships, '
          '${result.quizItems.length} quiz items '
          '(${result.quizItems.where((q) => q.rubric != null).length} '
          'with a rubric, ${result.rejectedRubricCount} rubrics rejected)',
        );

        // Auto-split high-difficulty items into sub-concepts
        final augmented = await _autoSplitHighDifficulty(
          result,
          extraction,
          docId,
        );

        // Merge into graph — staggered for live knowledge graph animation.
        // Register session concept IDs first so the live graph filter can
        // show nodes as they appear during staggered ingestion.
        state = state.copyWith(
          statusMessage: 'Adding ${augmented.concepts.length} concepts...',
          sessionConceptIds: state.sessionConceptIds.addAll(
            augmented.concepts.map((c) => c.id),
          ),
        );
        debugPrint('[Ingest] Adding concepts to graph...');
        try {
          await graphNotifier
              .staggeredIngestExtraction(
                augmented,
                documentId: docId,
                documentTitle: docTitle,
                updatedAt: updatedAt,
                collectionId: collectionId,
                collectionName: collectionName,
                documentText: content,
              )
              .timeout(
                const Duration(minutes: 2),
                onTimeout:
                    () =>
                        throw TimeoutException(
                          'Staggered ingestion timed out after 2 min',
                        ),
              );
          debugPrint('[Ingest] Saved successfully');
        } on TimeoutException {
          // No later write picks an extraction up again. If it never
          // committed, its document row wasn't written either, so the next
          // ingest re-extracts it instead of skipping it as unchanged.
          debugPrint(
            '[Ingest] Ingest of "$docTitle" timed out; '
            're-run ingest if its concepts are missing',
          );
          state = state.copyWith(
            statusMessage:
                'Timed out; re-run ingest if this document is missing',
          );
        }

        graph = ref.read(knowledgeGraphProvider).valueOrNull ?? graph;
        extracted++;
        state = state.copyWith(
          processedDocuments: extracted + skipped,
          extractedCount: extracted,
          statusMessage: '${augmented.concepts.length} concepts extracted',
        );
      }

      // Record the collection ID for sync checks
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.addIngestedCollectionId(collectionId);

      state = state.copyWith(phase: IngestPhase.done, currentDocumentTitle: '');
    } catch (e) {
      state = state.copyWith(
        phase: IngestPhase.error,
        errorMessage: 'Ingestion failed: $e',
      );
    }
  }

  /// Scales the extraction timeout based on document size.
  ///
  /// Base of 3 minutes plus 1 minute per 10K characters, capped at 8 minutes.
  /// Large documents produce more concepts/relationships/quiz items, so Claude
  /// needs proportionally more output tokens (and thus more time).
  static Duration _extractionTimeout(int contentLength) {
    final extraMinutes = (contentLength / 10000).ceil();
    final totalMinutes = (3 + extraMinutes).clamp(3, 8);
    return Duration(minutes: totalMinutes);
  }

  /// Auto-split quiz items with `predictedDifficulty > 8` into sub-concepts.
  ///
  /// Takes at most 3 items per document to avoid excessive API calls.
  /// Failures are non-fatal — the original high-difficulty items are kept
  /// regardless (FSRS mean reversion will adjust difficulty over time).
  Future<ExtractionResult> _autoSplitHighDifficulty(
    ExtractionResult result,
    ExtractionService extraction,
    String documentId,
  ) async {
    // Deduplicate by parent concept — multiple quiz items may reference
    // the same concept, but we only need to split each concept once.
    final seenConceptIds = <String>{};
    final itemsToSplit = <QuizItem>[];
    for (final item in result.quizItems) {
      if (item.predictedDifficulty != null &&
          item.predictedDifficulty! > 8.0 &&
          seenConceptIds.add(item.conceptId)) {
        itemsToSplit.add(item);
        if (itemsToSplit.length >= 3) break;
      }
    }

    if (itemsToSplit.isEmpty) return result;

    final newConcepts = <Concept>[];
    final newRelationships = <Relationship>[];
    final newQuizItems = <QuizItem>[];

    for (final item in itemsToSplit) {
      final parentConcept =
          result.concepts.where((c) => c.id == item.conceptId).firstOrNull;
      if (parentConcept == null) continue;

      state = state.copyWith(
        statusMessage: 'Splitting complex concept: ${parentConcept.name}...',
      );
      debugPrint(
        '[Ingest] Auto-splitting "${parentConcept.name}" '
        '(difficulty ${item.predictedDifficulty})',
      );

      try {
        final suggestion = await extraction.generateSubConcepts(
          parentConceptId: parentConcept.id,
          parentName: parentConcept.name,
          parentDescription: parentConcept.description,
          quizQuestion: item.question,
          quizAnswer: item.answer,
          sourceDocumentId: documentId,
        );
        debugPrint(
          '[Ingest] Split "${parentConcept.name}" into '
          '${suggestion.entries.length} sub-concepts '
          '(${suggestion.rejectedRubricCount} rubrics rejected)',
        );

        for (final entry in suggestion.entries) {
          newConcepts.add(entry.concept);
          newQuizItems.addAll(entry.quizItems);
          // Add composition relationship: sub-concept is part of parent
          newRelationships.add(
            Relationship(
              id: const Uuid().v4(),
              fromConceptId: entry.concept.id,
              toConceptId: parentConcept.id,
              label: 'is part of',
              type: RelationshipType.composition,
            ),
          );
        }

        debugPrint(
          '[Ingest] Split into ${suggestion.entries.length} sub-concepts',
        );
      } catch (e) {
        debugPrint(
          '[Ingest] Auto-split failed for "${parentConcept.name}": $e',
        );
        // Non-fatal — keep the original high-difficulty item
      }
    }

    if (newConcepts.isEmpty) return result;

    return ExtractionResult(
      concepts: [...result.concepts, ...newConcepts],
      relationships: [...result.relationships, ...newRelationships],
      quizItems: [...result.quizItems, ...newQuizItems],
    );
  }

  void reset() {
    state = IngestState.empty;
  }
}
