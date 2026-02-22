import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/graph_analyzer.dart';
import 'catastrophe_provider.dart';
import 'guardian_provider.dart';
import 'knowledge_graph_provider.dart';

/// Retention target for guardian-protected concepts (highest priority).
const guardianRetention = 0.97;

/// Retention target for active repair mission targets and hub concepts (3+
/// dependents).
const elevatedRetention = 0.95;

/// Retention target for standard concepts (1-2 dependents).
const standardRetention = 0.90;

/// Retention target for leaf concepts (0 dependents, lowest priority).
const leafRetention = 0.85;

/// Minimum number of dependents for a concept to be considered a hub.
const hubDependentThreshold = 3;

/// Per-concept desired retention for FSRS scheduling.
///
/// Returns a map of `conceptId → desired retention` (0.0–1.0). The FSRS
/// review engine uses this to adjust scheduling intervals — higher retention
/// means shorter intervals, lower means longer.
///
/// Priority (highest wins):
/// - Guardian-protected concept: [guardianRetention]
/// - Active repair mission target: [elevatedRetention]
/// - Hub concept ([hubDependentThreshold]+ dependents): [elevatedRetention]
/// - Standard concept: [standardRetention]
/// - Leaf concept (0 dependents): [leafRetention]
final desiredRetentionProvider = Provider<Map<String, double>>((ref) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null || graph.concepts.isEmpty) return const {};

  final analyzer = GraphAnalyzer(graph);

  // Collect guardian-protected concept IDs.
  final guardianState = ref.watch(guardianProvider);
  final guardedConceptIds = <String>{};
  for (final cluster in guardianState.myGuardedClusters) {
    guardedConceptIds.addAll(cluster.conceptIds);
  }

  // Collect active mission target concept IDs.
  final catastropheState = ref.watch(catastropheProvider);
  final missionConceptIds = <String>{};
  for (final mission in catastropheState.activeMissions) {
    missionConceptIds.addAll(mission.conceptIds);
  }

  final retentionMap = <String, double>{};

  for (final concept in graph.concepts) {
    final id = concept.id;

    // Guardian takes highest priority.
    if (guardedConceptIds.contains(id)) {
      retentionMap[id] = guardianRetention;
      continue;
    }

    // Active repair mission elevates retention.
    if (missionConceptIds.contains(id)) {
      retentionMap[id] = elevatedRetention;
      continue;
    }

    // Hub concept: important structural node with many dependents.
    final dependentCount = analyzer.dependentsOf(id).length;
    if (dependentCount >= hubDependentThreshold) {
      retentionMap[id] = elevatedRetention;
      continue;
    }

    // Leaf concept: 0 dependents → lower priority.
    if (dependentCount == 0) {
      retentionMap[id] = leafRetention;
      continue;
    }

    // Standard concept.
    retentionMap[id] = standardRetention;
  }

  return retentionMap;
});
