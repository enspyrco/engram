import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concept.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import '../models/topic.dart';
import 'clock_provider.dart';
import 'graph_store_provider.dart';

final knowledgeGraphProvider =
    AsyncNotifierProvider<KnowledgeGraphNotifier, KnowledgeGraph>(
      KnowledgeGraphNotifier.new,
    );

class KnowledgeGraphNotifier extends AsyncNotifier<KnowledgeGraph> {
  @override
  Future<KnowledgeGraph> build() async {
    // Seed from Firestore for pre-sync users (no-op if Drift already has data).
    await seedFromFirestoreIfNeeded(ref);

    final repo = ref.watch(graphRepositoryProvider);
    var graph = await repo.load();

    // Auto-migrate: generate one topic per collection from existing
    // document metadata if no topics exist yet.
    if (graph.topics.isEmpty && graph.documentMetadata.isNotEmpty) {
      graph = _autoMigrateTopics(graph);
      // Persist the migration
      unawaited(
        Future.wait(graph.topics.map(repo.upsertTopic)).catchError((e) {
          debugPrint('[KnowledgeGraph] Failed to persist topic migration: $e');
          return const <void>[];
        }),
      );
    }

    return graph;
  }

  /// Generate one topic per collection from existing document metadata.
  KnowledgeGraph _autoMigrateTopics(KnowledgeGraph graph) {
    final collectionDocs = <String, List<String>>{};
    final collectionNames = <String, String>{};
    final now = ref.read(clockProvider)();

    for (final meta in graph.documentMetadata) {
      final cId = meta.collectionId;
      final cName = meta.collectionName;
      if (cId != null && cName != null) {
        collectionDocs.putIfAbsent(cId, () => []).add(meta.documentId);
        collectionNames.putIfAbsent(cId, () => cName);
      }
    }

    var result = graph;
    for (final entry in collectionDocs.entries) {
      final topic = Topic(
        id: 'auto-${entry.key}',
        name: collectionNames[entry.key]!,
        description: 'Auto-migrated from collection',
        documentIds: entry.value.toSet(),
        createdAt: now,
      );
      result = result.withTopic(topic);
    }

    debugPrint(
      '[KnowledgeGraph] Auto-migrated ${collectionDocs.length} '
      'collection(s) to topics',
    );
    return result;
  }

  Future<void> reload() async {
    final repo = ref.read(graphRepositoryProvider);
    state = const AsyncLoading();
    state = AsyncData(await repo.load());
  }

  Future<void> updateQuizItem(QuizItem updated) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final newGraph = current.withUpdatedQuizItem(updated);
    state = AsyncData(newGraph);

    // Storage is best-effort — in-memory state is already correct.
    try {
      final repo = ref.read(graphRepositoryProvider);
      await repo.updateQuizItem(updated);
    } catch (e) {
      // Swallow storage errors so callers using unawaited() don't leak
      // uncaught futures. Log so failures are visible during debugging.
      debugPrint('[KnowledgeGraph] Storage error in updateQuizItem: $e');
    }
  }

  Future<void> ingestExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    String? collectionId,
    String? collectionName,
    String? documentText,
  }) async {
    final current = await future;

    final change = current.withExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
      documentText: documentText,
    );

    // Commit before publishing, so memory never shows a graph storage
    // rejected.
    final repo = ref.read(graphRepositoryProvider);
    await repo.applyExtraction(change.patch);
    state = AsyncData(change.graph);
  }

  /// Like [ingestExtraction] but reveals concepts in small batches with
  /// delays, so the force-directed graph animates arrivals without O(N²)
  /// graph rebuilds.
  Future<void> staggeredIngestExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    String? collectionId,
    String? collectionName,
    String? documentText,
    Duration delay = const Duration(milliseconds: 250),
    int batchSize = 3,
  }) async {
    final current = await future;

    // Persist the extraction the moment it is decided, so its clock is not
    // later than an edit made while the frames below animate it in.
    final change = current.withExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
      documentText: documentText,
    );
    final repo = ref.read(graphRepositoryProvider);
    await repo.applyExtraction(change.patch);

    // Step 1: Clear old concepts from this document (graph shrinks)
    final cleared = current.withNewExtraction(
      const ExtractionResult(concepts: [], relationships: [], quizItems: []),
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
      documentText: documentText,
    );
    state = AsyncData(cleared);
    await Future.delayed(delay);

    // Existing concept IDs in the graph (for cross-document relationships).
    final existingIds = cleared.concepts.map((c) => c.id).toSet();

    // Step 2: Add concepts in batches — each batch triggers one graph rebuild
    for (var i = 0; i < result.concepts.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, result.concepts.length);
      final revealedConcepts = result.concepts.sublist(0, end);
      final revealedIds = revealedConcepts.map((c) => c.id).toSet();
      // Include existing graph concepts so cross-document edges appear
      // as soon as their newly-extracted endpoint is revealed.
      final validIds = {...revealedIds, ...existingIds};

      final partial = ExtractionResult(
        concepts: revealedConcepts,
        relationships:
            result.relationships
                .where(
                  (r) =>
                      validIds.contains(r.fromConceptId) &&
                      validIds.contains(r.toConceptId),
                )
                .toList(),
        quizItems:
            result.quizItems
                .where((q) => revealedIds.contains(q.conceptId))
                .toList(),
      );

      final graph = cleared.withNewExtraction(
        partial,
        documentId: documentId,
        documentTitle: documentTitle,
        updatedAt: updatedAt,
        collectionId: collectionId,
        collectionName: collectionName,
        documentText: documentText,
      );
      state = AsyncData(graph);
      await Future.delayed(delay);
    }

    // Step 3: Settle on what storage holds, which includes any review, merge
    // or edit persisted while the frames were showing.
    state = AsyncData(await repo.load());
  }

  Future<void> splitConcept({
    required List<Concept> children,
    required List<Relationship> childRelationships,
    required List<QuizItem> childQuizItems,
  }) async {
    final current = await future;

    final newGraph = current.withConceptSplit(
      children: children,
      childRelationships: childRelationships,
      childQuizItems: childQuizItems,
    );
    state = AsyncData(newGraph);

    final repo = ref.read(graphRepositoryProvider);
    await repo.saveSplitData(
      concepts: children,
      relationships: childRelationships,
      quizItems: childQuizItems,
    );
  }

  /// Update a document's metadata with its collection info and persist
  /// only its collection columns.
  void backfillCollectionInfo(
    String documentId, {
    required String collectionId,
    required String collectionName,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;

    final newGraph = current.withDocumentCollectionInfo(
      documentId,
      collectionId: collectionId,
      collectionName: collectionName,
    );
    if (identical(newGraph, current)) return;
    state = AsyncData(newGraph);

    // Fire-and-forget — in-memory state is already correct.
    final repo = ref.read(graphRepositoryProvider);
    repo
        .setDocumentCollection(
          documentId,
          collectionId: collectionId,
          collectionName: collectionName,
        )
        .catchError((e) {
          debugPrint(
            '[KnowledgeGraph] Storage error in backfillCollectionInfo: $e',
          );
        });
  }

  /// Upsert [topic] into the graph and persist it. [previous] is the copy
  /// the caller edited [topic] from (null for a new topic); only the
  /// document links that differ between the two are written.
  void upsertTopic(Topic topic, {required Topic? previous}) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.withTopic(topic));

    // Storage is written whether or not the graph has loaded into memory.
    final repo = ref.read(graphRepositoryProvider);
    repo.upsertTopic(topic, previous: previous).catchError((e) {
      debugPrint('[KnowledgeGraph] Storage error in upsertTopic: $e');
    });
  }

  /// Record that [topicId] finished ingesting now, persisting only that
  /// column.
  void markTopicIngested(String topicId) {
    final now = ref.read(clockProvider)();
    final current = state.valueOrNull;
    final topic = current?.topics.where((t) => t.id == topicId).firstOrNull;
    if (current != null && topic != null) {
      state = AsyncData(current.withTopic(topic.withLastIngestedAt(now)));
    }

    // Storage is written whether or not the graph has loaded into memory.
    final repo = ref.read(graphRepositoryProvider);
    repo.markTopicIngested(topicId, now).catchError((e) {
      debugPrint('[KnowledgeGraph] Storage error in markTopicIngested: $e');
    });
  }

  void setGraph(KnowledgeGraph graph) {
    state = AsyncData(graph);
  }
}
