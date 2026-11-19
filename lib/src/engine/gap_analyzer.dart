import '../models/concept_cluster.dart';
import '../models/knowledge_gap.dart';
import '../models/knowledge_graph.dart';
import '../models/relationship.dart';
import 'cluster_detector.dart';
import 'graph_analyzer.dart';
import 'mastery_state.dart';

/// Pure engine that detects structural gaps in a [KnowledgeGraph].
///
/// No Flutter dependency. Testable in isolation. Takes a graph and optional
/// precomputed clusters, returns gaps sorted by severity descending.
///
/// **Four detection algorithms:**
///
/// 1. **Cluster isolation** — cluster pairs with no cross-cluster edges.
/// 2. **Structural thinness** — important concepts (have quiz items) with
///    degree <= 1, needing enrichment.
/// 3. **Relationship type gaps** — clusters dominated by prerequisite chains
///    with no lateral relationships (analogy, contrast, enables).
/// 4. **Critical bottlenecks** — high out-degree concepts with low mastery
///    that block many dependents.
class GapAnalyzer {
  GapAnalyzer(this._graph, {List<ConceptCluster>? clusters, DateTime? now})
    : _clusters = clusters,
      _now = now;

  final KnowledgeGraph _graph;
  final List<ConceptCluster>? _clusters;
  final DateTime? _now;

  /// Undirected degree of each concept (count of all relationships, both
  /// directions).
  late final Map<String, int> _degree = _buildDegree();

  /// Concept ID → name lookup.
  late final Map<String, String> _conceptNames = {
    for (final c in _graph.concepts) c.id: c.name,
  };

  /// Concept IDs that have at least one quiz item.
  late final Set<String> _hasQuizItems = {
    for (final q in _graph.quizItems) q.conceptId,
  };

  /// Analyze the graph and return all detected gaps, sorted by severity
  /// descending.
  List<KnowledgeGap> analyze() {
    if (_graph.concepts.isEmpty) return [];

    final gaps = <KnowledgeGap>[
      ..._detectClusterIsolation(),
      ..._detectStructuralThinness(),
      ..._detectRelationshipTypeGaps(),
      ..._detectCriticalBottlenecks(),
    ];

    gaps.sort((a, b) => b.severity.compareTo(a.severity));
    return gaps;
  }

  // ── 1. Cluster isolation ─────────────────────────────────────────

  /// For each pair of clusters, check for cross-cluster edges. No bridge
  /// between two clusters = a gap. Severity scales with the product of
  /// cluster sizes (bigger isolated clusters = worse).
  List<KnowledgeGap> _detectClusterIsolation() {
    final clusters = _clusters ?? ClusterDetector(_graph).detect();
    if (clusters.length < 2) return [];

    // Build a set of edges for O(1) lookup.
    final edgeSet = <String>{};
    for (final r in _graph.relationships) {
      edgeSet.add('${r.fromConceptId}|${r.toConceptId}');
      edgeSet.add('${r.toConceptId}|${r.fromConceptId}');
    }

    final gaps = <KnowledgeGap>[];

    for (var i = 0; i < clusters.length; i++) {
      for (var j = i + 1; j < clusters.length; j++) {
        final a = clusters[i];
        final b = clusters[j];

        // Check for any cross-cluster edge.
        var hasBridge = false;
        for (final aId in a.conceptIds) {
          for (final bId in b.conceptIds) {
            if (edgeSet.contains('$aId|$bId')) {
              hasBridge = true;
              break;
            }
          }
          if (hasBridge) break;
        }

        if (hasBridge) continue;

        final sizeProduct = a.conceptIds.length * b.conceptIds.length;
        // Severity: product of sizes as an absolute measure of missing
        // connectivity, capped at 1.0. Two 5-node clusters isolated from
        // each other (product 25) is the "maximum severity" reference.
        const maxProductRef = 25.0;
        final severity = (sizeProduct / maxProductRef).clamp(0.0, 1.0);

        // Bridge potential is high — connecting clusters creates many
        // new conceptual paths.
        final bridgePotential = (sizeProduct / 10.0).clamp(0.0, 1.0);

        // Combine concept names from both clusters for search terms.
        final searchTerms = <String>[
          ..._clusterConceptNames(a),
          ..._clusterConceptNames(b),
        ];

        gaps.add(
          KnowledgeGap(
            type: GapType.clusterIsolation,
            description:
                'Clusters "${a.label}" and "${b.label}" have no connections. '
                'Bridging them could create $sizeProduct new conceptual paths.',
            severity: severity,
            bridgePotential: bridgePotential,
            involvedConceptIds: [...a.conceptIds, ...b.conceptIds],
            involvedClusterLabels: [a.label, b.label],
            suggestedSearchTerms: searchTerms,
          ),
        );
      }
    }

    return gaps;
  }

  // ── 2. Structural thinness ───────────────────────────────────────

  /// Concepts with degree <= 1 that have quiz items (i.e. they're "real"
  /// learning content, not just informational nodes). These need more
  /// connections to be well-integrated into the graph.
  List<KnowledgeGap> _detectStructuralThinness() {
    final gaps = <KnowledgeGap>[];
    final totalConcepts = _graph.concepts.length;

    for (final concept in _graph.concepts) {
      final degree = _degree[concept.id] ?? 0;
      if (degree > 1) continue;
      if (!_hasQuizItems.contains(concept.id)) continue;

      // Severity: degree 0 is worse than degree 1.
      // Normalize by considering how isolated this concept is relative
      // to the average degree in the graph.
      final severity = degree == 0 ? 0.7 : 0.4;

      // Bridge potential scales with how many concepts exist to connect to.
      final bridgePotential =
          totalConcepts > 1 ? (1.0 - 1.0 / totalConcepts).clamp(0.0, 1.0) : 0.0;

      gaps.add(
        KnowledgeGap(
          type: GapType.structuralThinness,
          description:
              '"${concept.name}" has only $degree connection(s) but contains '
              'quiz material. Adding more relationships would deepen '
              'understanding.',
          severity: severity,
          bridgePotential: bridgePotential,
          involvedConceptIds: [concept.id],
          suggestedSearchTerms: [concept.name],
        ),
      );
    }

    return gaps;
  }

  // ── 3. Relationship type gaps ────────────────────────────────────

  /// Clusters that are pure prerequisite chains with no lateral relationships
  /// (analogy, contrast, enables). Missing lateral connections mean the
  /// learner can recite a dependency chain but can't transfer or compare.
  List<KnowledgeGap> _detectRelationshipTypeGaps() {
    final clusters = _clusters ?? ClusterDetector(_graph).detect();

    // Index: fromConceptId|toConceptId → resolved relationship type.
    // We only need to know which types exist within each cluster.
    final relationshipsByEndpoints = <String, Set<RelationshipType>>{};
    for (final r in _graph.relationships) {
      final key = '${r.fromConceptId}|${r.toConceptId}';
      relationshipsByEndpoints.putIfAbsent(key, () => {}).add(r.resolvedType);
    }

    /// Lateral types that indicate deeper understanding connections.
    const lateralTypes = {
      RelationshipType.analogy,
      RelationshipType.contrast,
      RelationshipType.enables,
      RelationshipType.generalization,
      RelationshipType.composition,
    };

    final gaps = <KnowledgeGap>[];

    for (final cluster in clusters) {
      if (cluster.conceptIds.length < 2) continue;

      final clusterIds = cluster.conceptIds.toSet();

      // Count relationship types within this cluster.
      var totalEdges = 0;
      var hasLateral = false;

      for (final r in _graph.relationships) {
        final fromIn = clusterIds.contains(r.fromConceptId);
        final toIn = clusterIds.contains(r.toConceptId);
        if (!fromIn || !toIn) continue;

        totalEdges++;
        if (lateralTypes.contains(r.resolvedType)) {
          hasLateral = true;
          break; // One lateral edge is enough to clear this cluster.
        }
      }

      if (totalEdges < 2 || hasLateral) continue;

      // All intra-cluster edges are prerequisite/relatedTo chains.
      gaps.add(
        KnowledgeGap(
          type: GapType.relationshipTypeGap,
          description:
              'Cluster "${cluster.label}" has $totalEdges edges but no '
              'lateral relationships (analogy, contrast, enables). Adding '
              'them would deepen understanding beyond linear dependency.',
          severity: 0.5,
          bridgePotential: 0.6,
          involvedConceptIds: cluster.conceptIds.toList(),
          involvedClusterLabels: [cluster.label],
          suggestedSearchTerms: _clusterConceptNames(cluster),
        ),
      );
    }

    return gaps;
  }

  // ── 4. Critical bottlenecks ──────────────────────────────────────

  /// High out-degree concepts (many dependents) with low mastery. The graph
  /// needs alternative paths around these chokepoints so learners aren't
  /// permanently blocked.
  List<KnowledgeGap> _detectCriticalBottlenecks() {
    final analyzer = GraphAnalyzer(_graph);
    final gaps = <KnowledgeGap>[];

    for (final concept in _graph.concepts) {
      final dependents = analyzer.dependentsOf(concept.id);
      if (dependents.length < 2) continue;

      final state = masteryStateOf(concept.id, _graph, analyzer, now: _now);

      // Only flag concepts that are not yet mastered.
      if (state == MasteryState.mastered || state == MasteryState.fading) {
        continue;
      }

      // Severity scales with the number of blocked dependents.
      final severity = (dependents.length / _graph.concepts.length).clamp(
        0.0,
        1.0,
      );

      gaps.add(
        KnowledgeGap(
          type: GapType.criticalBottleneck,
          description:
              '"${concept.name}" blocks ${dependents.length} other concepts '
              'and has not been mastered. Alternative learning paths could '
              'reduce this bottleneck.',
          severity: severity,
          bridgePotential: 0.8,
          involvedConceptIds: [concept.id, ...dependents],
          suggestedSearchTerms: [
            concept.name,
            ...dependents
                .take(3)
                .map((id) => _conceptNames[id])
                .whereType<String>(),
          ],
        ),
      );
    }

    return gaps;
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Map<String, int> _buildDegree() {
    final deg = <String, int>{};
    for (final r in _graph.relationships) {
      deg[r.fromConceptId] = (deg[r.fromConceptId] ?? 0) + 1;
      deg[r.toConceptId] = (deg[r.toConceptId] ?? 0) + 1;
    }
    return deg;
  }

  /// Extract concept names from a cluster for use as search terms.
  List<String> _clusterConceptNames(ConceptCluster cluster) {
    return cluster.conceptIds
        .map((id) => _conceptNames[id])
        .whereType<String>()
        .toList();
  }
}
