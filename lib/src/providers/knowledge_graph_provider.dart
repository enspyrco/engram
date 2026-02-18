import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concept.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import '../models/topic.dart';
import 'graph_store_provider.dart';

final knowledgeGraphProvider =
    AsyncNotifierProvider<KnowledgeGraphNotifier, KnowledgeGraph>(
  KnowledgeGraphNotifier.new,
);

class KnowledgeGraphNotifier extends AsyncNotifier<KnowledgeGraph> {
  @override
  Future<KnowledgeGraph> build() async {
    final repo = ref.watch(graphRepositoryProvider);
    var graph = await repo.load();

    // Auto-migrate: generate one topic per collection from existing
    // document metadata if no topics exist yet.
    if (graph.topics.isEmpty && graph.documentMetadata.isNotEmpty) {
      graph = _autoMigrateTopics(graph);
      // Persist the migration
      unawaited(repo.save(graph).catchError((e) {
        debugPrint('[KnowledgeGraph] Failed to persist topic migration: $e');
      }));
    }

    return graph;
  }

  /// Generate one topic per collection from existing document metadata.
  KnowledgeGraph _autoMigrateTopics(KnowledgeGraph graph) {
    final collectionDocs = <String, List<String>>{};
    final collectionNames = <String, String>{};
    final now = DateTime.now().toUtc().toIso8601String();

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

    debugPrint('[KnowledgeGraph] Auto-migrated ${collectionDocs.length} '
        'collection(s) to topics');
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
      await repo.updateQuizItem(newGraph, updated);
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
  }) async {
    final current = await future;

    final newGraph = current.withNewExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
    );
    state = AsyncData(newGraph);

    final repo = ref.read(graphRepositoryProvider);
    await repo.save(newGraph);
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
    Duration delay = const Duration(milliseconds: 250),
    int batchSize = 3,
  }) async {
    final current = await future;

    // Step 1: Clear old concepts from this document (graph shrinks)
    final cleared = current.withNewExtraction(
      const ExtractionResult(
        concepts: [],
        relationships: [],
        quizItems: [],
      ),
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
    );
    state = AsyncData(cleared);
    await Future.delayed(delay);

    // Step 2: Add concepts in batches — each batch triggers one graph rebuild
    for (var i = 0; i < result.concepts.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, result.concepts.length);
      final revealedConcepts = result.concepts.sublist(0, end);
      final revealedIds = revealedConcepts.map((c) => c.id).toSet();

      final partial = ExtractionResult(
        concepts: revealedConcepts,
        relationships: result.relationships
            .where((r) =>
                revealedIds.contains(r.fromConceptId) &&
                revealedIds.contains(r.toConceptId))
            .toList(),
        quizItems: result.quizItems
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
      );
      state = AsyncData(graph);
      await Future.delayed(delay);
    }

    // Step 3: Persist the final state
    final finalGraph = state.valueOrNull;
    if (finalGraph != null) {
      final repo = ref.read(graphRepositoryProvider);
      await repo.save(finalGraph);
    }
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
      graph: newGraph,
      concepts: children,
      relationships: childRelationships,
      quizItems: childQuizItems,
    );
  }

  /// Update in-memory metadata with collection info for a document.
  /// When [skipPersist] is true, the caller is responsible for batching the
  /// save (e.g. after a loop of backfills).
  void backfillCollectionInfo(
    String documentId, {
    required String collectionId,
    required String collectionName,
    bool skipPersist = false,
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

    if (skipPersist) return;

    // Fire-and-forget — in-memory state is already correct.
    final repo = ref.read(graphRepositoryProvider);
    repo.save(newGraph).catchError((e) {
      debugPrint('[KnowledgeGraph] Storage error in backfillCollectionInfo: $e');
    });
  }

  /// Upsert a topic into the graph and persist.
  void upsertTopic(Topic topic) {
    final current = state.valueOrNull;
    if (current == null) return;

    final newGraph = current.withTopic(topic);
    state = AsyncData(newGraph);

    final repo = ref.read(graphRepositoryProvider);
    repo.save(newGraph).catchError((e) {
      debugPrint('[KnowledgeGraph] Storage error in upsertTopic: $e');
    });
  }

  void setGraph(KnowledgeGraph graph) {
    state = AsyncData(graph);
  }
}
