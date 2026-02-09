import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/graph_analyzer.dart';
import 'knowledge_graph_provider.dart';

final graphAnalysisProvider = Provider<GraphAnalyzer?>((ref) {
  final graphAsync = ref.watch(knowledgeGraphProvider);
  final graph = graphAsync.valueOrNull;
  if (graph == null || graph.concepts.isEmpty) return null;
  return GraphAnalyzer(graph);
});
