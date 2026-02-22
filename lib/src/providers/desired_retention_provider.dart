import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/graph_analyzer.dart';
import 'catastrophe_provider.dart';
import 'guardian_provider.dart';
import 'knowledge_graph_provider.dart';

/// Per-concept desired retention for FSRS scheduling.
///
/// Returns a map of `conceptId → desired retention` (0.0–1.0). The FSRS
/// review engine uses this to adjust scheduling intervals — higher retention
/// means shorter intervals, lower means longer.
///
/// Priority (highest wins):
/// - Guardian-protected concept: 0.97
/// - Active repair mission target: 0.95
/// - Hub concept (3+ dependents): 0.95
/// - Standard concept: 0.90
/// - Leaf concept (0 dependents): 0.85
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
      retentionMap[id] = 0.97;
      continue;
    }

    // Active repair mission elevates retention.
    if (missionConceptIds.contains(id)) {
      retentionMap[id] = 0.95;
      continue;
    }

    // Hub concept: 3+ dependents → important structural node.
    final dependentCount = analyzer.dependentsOf(id).length;
    if (dependentCount >= 3) {
      retentionMap[id] = 0.95;
      continue;
    }

    // Leaf concept: 0 dependents → lower priority.
    if (dependentCount == 0) {
      retentionMap[id] = 0.85;
      continue;
    }

    // Standard concept.
    retentionMap[id] = 0.90;
  }

  return retentionMap;
});
