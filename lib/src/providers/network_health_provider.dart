import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/network_health_scorer.dart';
import '../models/network_health.dart';
import 'cluster_provider.dart';
import 'knowledge_graph_provider.dart';

/// Provides the current [NetworkHealth] derived from the knowledge graph.
///
/// Recomputes whenever the graph changes. Pure derived state — no side effects,
/// no Firestore writes. The [CatastropheNotifier] watches this and handles
/// persistence and event generation.
final networkHealthProvider = Provider<NetworkHealth>((ref) {
  final graphAsync = ref.watch(knowledgeGraphProvider);
  final graph = graphAsync.valueOrNull;
  if (graph == null || graph.concepts.isEmpty) {
    return const NetworkHealth(score: 1.0, tier: HealthTier.healthy);
  }
  final clusters = ref.watch(clusterProvider);
  return NetworkHealthScorer(
    graph,
    clusters: clusters,
  ).score();
});
