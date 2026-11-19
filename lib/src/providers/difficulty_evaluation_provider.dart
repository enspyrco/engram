import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/difficulty_evaluation.dart';
import 'knowledge_graph_provider.dart';

/// Computed evaluation of Claude's difficulty predictions vs FSRS actuals.
///
/// Watches [knowledgeGraphProvider] and recomputes on graph changes.
/// Returns [DifficultyEvaluationResult.empty] when the graph is not loaded.
final difficultyEvaluationProvider = Provider<DifficultyEvaluationResult>((
  ref,
) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null) return DifficultyEvaluationResult.empty();
  return evaluatePredictions(graph.quizItems.toList());
});
