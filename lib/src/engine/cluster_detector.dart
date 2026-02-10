import '../models/concept.dart';
import '../models/concept_cluster.dart';
import '../models/knowledge_graph.dart';

/// Detects communities (clusters) in a concept graph using label propagation.
///
/// Pure Dart, no Flutter dependency. Works on the undirected version of the
/// relationship graph — every edge is treated as bidirectional regardless of
/// the original label direction.
class ClusterDetector {
  ClusterDetector(this._graph);

  final KnowledgeGraph _graph;

  /// Run label propagation and return detected clusters.
  ///
  /// Each cluster gets a human-readable label derived from its most-connected
  /// concept (the "hub" whose name best represents the group).
  List<ConceptCluster> detect({int maxIterations = 50}) {
    if (_graph.concepts.isEmpty) return [];

    // Build undirected adjacency list
    final adjacency = <String, List<String>>{};
    for (final c in _graph.concepts) {
      adjacency[c.id] = [];
    }
    for (final r in _graph.relationships) {
      adjacency[r.fromConceptId]?.add(r.toConceptId);
      adjacency[r.toConceptId]?.add(r.fromConceptId);
    }

    // Initialize: each node gets its own label
    final labels = <String, String>{
      for (final c in _graph.concepts) c.id: c.id,
    };

    // Iterate until convergence or max iterations
    for (var i = 0; i < maxIterations; i++) {
      var changed = false;

      for (final concept in _graph.concepts) {
        final neighbors = adjacency[concept.id]!;
        if (neighbors.isEmpty) continue;

        // Count neighbor labels
        final counts = <String, int>{};
        for (final neighbor in neighbors) {
          final label = labels[neighbor]!;
          counts[label] = (counts[label] ?? 0) + 1;
        }

        // Pick most common label (ties broken by smallest label for determinism)
        var bestLabel = labels[concept.id]!;
        var bestCount = 0;
        for (final entry in counts.entries) {
          if (entry.value > bestCount ||
              (entry.value == bestCount &&
                  entry.key.compareTo(bestLabel) < 0)) {
            bestLabel = entry.key;
            bestCount = entry.value;
          }
        }

        if (labels[concept.id] != bestLabel) {
          labels[concept.id] = bestLabel;
          changed = true;
        }
      }

      if (!changed) break;
    }

    // Group concepts by label
    final groups = <String, List<String>>{};
    for (final entry in labels.entries) {
      groups.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    // Build clusters with human-readable names
    final conceptMap = <String, Concept>{
      for (final c in _graph.concepts) c.id: c,
    };

    return groups.entries.map((entry) {
      // Name the cluster after its most-connected concept
      final conceptIds = entry.value;
      var hubId = conceptIds.first;
      var maxDegree = 0;
      for (final id in conceptIds) {
        final degree = adjacency[id]?.length ?? 0;
        if (degree > maxDegree) {
          maxDegree = degree;
          hubId = id;
        }
      }

      return ConceptCluster(
        label: conceptMap[hubId]?.name ?? hubId,
        conceptIds: conceptIds,
      );
    }).toList();
  }
}
