import '../models/concept_cluster.dart';
import '../models/knowledge_graph.dart';
import '../models/network_health.dart';
import 'cluster_detector.dart';
import 'graph_analyzer.dart';
import 'mastery_state.dart';

/// Pure scoring engine that computes [NetworkHealth] from a [KnowledgeGraph].
///
/// No Flutter dependency. Testable in isolation. The scoring formula:
///
///   base = 0.5 * masteryRatio + 0.3 * learningRatio + 0.2 * avgFreshness
///   score = base × (1.0 - 0.1 * atRiskCriticalPaths / totalCriticalPaths)
///
/// "Critical path" concepts are those with high out-degree in the dependency
/// graph — many other concepts depend on them, so their decay has outsized
/// impact on the team's ability to learn.
class NetworkHealthScorer {
  NetworkHealthScorer(
    this._graph, {
    DateTime? now,
    List<ConceptCluster>? clusters,
  }) : _now = now,
       _clusters = clusters;

  final KnowledgeGraph _graph;
  final DateTime? _now;
  final List<ConceptCluster>? _clusters;

  /// Minimum out-degree for a concept to be considered a critical path node.
  static const criticalPathThreshold = 2;

  /// Compute the full network health assessment.
  NetworkHealth score() {
    if (_graph.concepts.isEmpty) {
      return const NetworkHealth(score: 1.0, tier: HealthTier.healthy);
    }

    final analyzer = GraphAnalyzer(_graph);
    final total = _graph.concepts.length;

    // Classify every concept
    var masteredCount = 0;
    var learningCount = 0;
    double freshnessSum = 0;

    for (final concept in _graph.concepts) {
      final state = masteryStateOf(concept.id, _graph, analyzer, now: _now);
      switch (state) {
        case MasteryState.mastered:
        case MasteryState.fading:
          masteredCount++;
        case MasteryState.learning:
          learningCount++;
        case MasteryState.locked:
        case MasteryState.due:
          break;
      }
      freshnessSum += freshnessOf(
        concept.id,
        _graph,
        now: _now,
      );
    }

    final masteryRatio = masteredCount / total;
    final learningRatio = learningCount / total;
    final avgFreshness = freshnessSum / total;

    // Critical path analysis: concepts with high out-degree in the
    // dependency graph (many others depend on them).
    final criticalPaths = <String>[];
    for (final concept in _graph.concepts) {
      final dependents = analyzer.dependentsOf(concept.id);
      if (dependents.length >= criticalPathThreshold) {
        criticalPaths.add(concept.id);
      }
    }

    final totalCriticalPaths = criticalPaths.length;
    var atRiskCriticalPaths = 0;
    for (final id in criticalPaths) {
      final state = masteryStateOf(id, _graph, analyzer, now: _now);
      if (state == MasteryState.fading ||
          state == MasteryState.due ||
          state == MasteryState.locked) {
        atRiskCriticalPaths++;
      }
    }

    // Composite score
    final base = 0.5 * masteryRatio + 0.3 * learningRatio + 0.2 * avgFreshness;
    final criticalPenalty =
        totalCriticalPaths > 0
            ? 1.0 - 0.1 * (atRiskCriticalPaths / totalCriticalPaths)
            : 1.0;
    final rawScore = (base * criticalPenalty).clamp(0.0, 1.0);

    // Per-cluster health
    final clusters = _clusters ?? ClusterDetector(_graph).detect();
    final clusterHealth = _computeClusterHealth(clusters, analyzer);

    return NetworkHealth(
      score: rawScore,
      tier: NetworkHealth.tierFromScore(rawScore),
      masteryRatio: masteryRatio,
      learningRatio: learningRatio,
      avgFreshness: avgFreshness,
      atRiskCriticalPaths: atRiskCriticalPaths,
      totalCriticalPaths: totalCriticalPaths,
      clusterHealth: clusterHealth,
    );
  }

  /// Compute health per cluster — same formula but scoped to cluster concepts.
  Map<String, double> _computeClusterHealth(
    List<ConceptCluster> clusters,
    GraphAnalyzer analyzer,
  ) {
    final result = <String, double>{};

    for (final cluster in clusters) {
      if (cluster.conceptIds.isEmpty) continue;

      final clusterConcepts =
          _graph.concepts
              .where((c) => cluster.conceptIds.contains(c.id))
              .toList();
      final total = clusterConcepts.length;
      if (total == 0) continue;

      var mastered = 0;
      var learning = 0;
      double freshness = 0;

      for (final concept in clusterConcepts) {
        final state = masteryStateOf(concept.id, _graph, analyzer, now: _now);
        switch (state) {
          case MasteryState.mastered:
          case MasteryState.fading:
            mastered++;
          case MasteryState.learning:
            learning++;
          case MasteryState.locked:
          case MasteryState.due:
            break;
        }
        freshness += freshnessOf(
          concept.id,
          _graph,
          now: _now,
        );
      }

      final clusterScore = (0.5 * mastered / total +
              0.3 * learning / total +
              0.2 * freshness / total)
          .clamp(0.0, 1.0);

      result[cluster.label] = clusterScore;
    }

    return result;
  }
}
