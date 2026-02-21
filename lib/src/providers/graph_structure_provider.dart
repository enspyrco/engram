import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/knowledge_graph.dart';
import '../models/relationship.dart';
import 'knowledge_graph_provider.dart';

/// Structural view of the knowledge graph: concepts + relationships only.
///
/// Uses [select] so quiz-item-only mutations (the most frequent update path)
/// do NOT trigger downstream rebuilds. This works because
/// [KnowledgeGraph.withUpdatedQuizItem] reuses the same [IList] references
/// for concepts and relationships — value equality short-circuits the select.
///
/// Consumers that only need graph topology (cluster detection, empty-state
/// checks, concept name lookups) should watch this instead of
/// [knowledgeGraphProvider].
final graphStructureProvider = Provider<KnowledgeGraph?>((ref) {
  final concepts = ref.watch(
    knowledgeGraphProvider.select(
      (AsyncValue<KnowledgeGraph> av) => av.valueOrNull?.concepts,
    ),
  );
  final relationships = ref.watch(
    knowledgeGraphProvider.select(
      (AsyncValue<KnowledgeGraph> av) => av.valueOrNull?.relationships,
    ),
  );

  if (concepts == null || concepts.isEmpty) return null;

  return KnowledgeGraph(
    concepts: concepts.toList(),
    relationships:
        (relationships ?? const IListConst<Relationship>([])).toList(),
  );
});
