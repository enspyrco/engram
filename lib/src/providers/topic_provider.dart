import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/knowledge_graph.dart';
import '../models/topic.dart';
import 'knowledge_graph_provider.dart';

/// All topics from the knowledge graph, sorted by name.
final availableTopicsProvider = Provider<IList<Topic>>((ref) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null) return const IListConst([]);
  return graph.topics.sort((a, b) => a.name.compareTo(b.name));
});

/// Currently selected topic for quiz filtering. `null` means all.
final selectedTopicIdProvider = StateProvider<String?>((ref) => null);

/// Graph filtered to concepts from a topic's document set.
final topicFilteredGraphProvider =
    Provider.family<KnowledgeGraph?, String>((ref, topicId) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null) return null;

  final topic = graph.topics.where((t) => t.id == topicId).firstOrNull;
  if (topic == null) return graph;

  final docIds = topic.documentIds;
  final conceptIds = graph.concepts
      .where((c) => docIds.contains(c.sourceDocumentId))
      .map((c) => c.id)
      .toSet();

  return KnowledgeGraph(
    concepts: graph.concepts
        .where((c) => conceptIds.contains(c.id))
        .toList(),
    relationships: graph.relationships
        .where((r) =>
            conceptIds.contains(r.fromConceptId) &&
            conceptIds.contains(r.toConceptId))
        .toList(),
    quizItems: graph.quizItems
        .where((q) => conceptIds.contains(q.conceptId))
        .toList(),
    documentMetadata: graph.documentMetadata
        .where((m) => docIds.contains(m.documentId))
        .toList(),
    topics: graph.topics.toList(),
  );
});
