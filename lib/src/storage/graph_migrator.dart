import '../models/knowledge_graph.dart';
import 'graph_repository.dart';

/// Migrates a knowledge graph from one repository to another.
///
/// Used for local JSON → Firestore migration when cloud sync is first enabled,
/// and for Firestore → local fallback when cloud sync is disabled.
class GraphMigrator {
  const GraphMigrator({
    required GraphRepository source,
    required GraphRepository destination,
  })  : _source = source,
        _destination = destination;

  final GraphRepository _source;
  final GraphRepository _destination;

  /// Load from source and save to destination.
  /// Returns the migrated graph, or [KnowledgeGraph.empty] if source is empty.
  Future<KnowledgeGraph> migrate() async {
    final graph = await _source.load();
    if (graph.concepts.isNotEmpty ||
        graph.relationships.isNotEmpty ||
        graph.quizItems.isNotEmpty ||
        graph.documentMetadata.isNotEmpty) {
      await _destination.save(graph);
    }
    return graph;
  }
}
