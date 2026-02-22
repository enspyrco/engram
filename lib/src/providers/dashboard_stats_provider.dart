import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/scheduler.dart';
import '../models/dashboard_stats.dart';
import 'graph_analysis_provider.dart';
import 'knowledge_graph_provider.dart';

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final graphAsync = ref.watch(knowledgeGraphProvider);
  final graph = graphAsync.valueOrNull;
  if (graph == null || graph.concepts.isEmpty) {
    return const DashboardStats();
  }

  var newCount = 0;
  var learningCount = 0;
  var masteredCount = 0;

  for (final item in graph.quizItems) {
    if (item.lastReview == null) {
      newCount++;
    } else if (item.interval < 21) {
      learningCount++;
    } else {
      masteredCount++;
    }
  }

  final dueItems = scheduleDueItems(graph);
  final analyzer = ref.watch(graphAnalysisProvider);

  return DashboardStats(
    documentCount: graph.documentMetadata.length,
    conceptCount: graph.concepts.length,
    relationshipCount: graph.relationships.length,
    quizItemCount: graph.quizItems.length,
    newCount: newCount,
    learningCount: learningCount,
    masteredCount: masteredCount,
    dueCount: dueItems.length,
    foundationalCount: analyzer?.foundationalConcepts.length ?? 0,
    unlockedCount: analyzer?.unlockedConcepts.length ?? 0,
    lockedCount: analyzer?.lockedConcepts.length ?? 0,
    hasCycles: analyzer?.hasCycles() ?? false,
  );
});
