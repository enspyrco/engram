import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/scheduler.dart';
import '../models/knowledge_graph.dart';
import 'collection_filter_provider.dart';
import 'knowledge_graph_provider.dart';

/// A derived view of the knowledge graph filtered by the selected collection.
///
/// When [selectedCollectionIdProvider] is `null`, returns the full graph.
/// When a collection is selected, returns only concepts whose source document
/// belongs to that collection, plus relationships where both endpoints are in
/// the subgraph, and quiz items for the remaining concepts.
final filteredGraphProvider = Provider<KnowledgeGraph?>((ref) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null) return null;

  final collectionId = ref.watch(selectedCollectionIdProvider);
  if (collectionId == null) return graph;

  // Find document IDs belonging to the selected collection.
  final docIds = <String>{};
  for (final meta in graph.documentMetadata) {
    if (meta.collectionId == collectionId) {
      docIds.add(meta.documentId);
    }
  }

  // Filter concepts by source document membership.
  final concepts =
      graph.concepts.where((c) => docIds.contains(c.sourceDocumentId)).toList();
  final conceptIds = concepts.map((c) => c.id).toSet();

  // Keep only relationships where both endpoints survive.
  final relationships =
      graph.relationships
          .where(
            (r) =>
                conceptIds.contains(r.fromConceptId) &&
                conceptIds.contains(r.toConceptId),
          )
          .toList();

  // Keep quiz items for surviving concepts.
  final quizItems =
      graph.quizItems.where((q) => conceptIds.contains(q.conceptId)).toList();

  // Keep metadata for the selected collection's documents.
  final metadata =
      graph.documentMetadata
          .where((m) => docIds.contains(m.documentId))
          .toList();

  return KnowledgeGraph(
    concepts: concepts,
    relationships: relationships,
    quizItems: quizItems,
    documentMetadata: metadata,
  );
});

/// Compact stats derived from the filtered graph for the dashboard overlay.
///
/// Cached by Riverpod — only recomputes when [filteredGraphProvider] changes.
final filteredStatsProvider = Provider<({int concepts, int mastered, int due})>(
  (ref) {
    final graph = ref.watch(filteredGraphProvider);
    if (graph == null) return (concepts: 0, mastered: 0, due: 0);

    return (
      concepts: graph.concepts.length,
      mastered: graph.quizItems.where((q) => q.interval >= 21).length,
      due: scheduleDueItems(graph, maxItems: null).length,
    );
  },
);
