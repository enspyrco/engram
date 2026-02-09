import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import 'graph_store_provider.dart';

final knowledgeGraphProvider =
    AsyncNotifierProvider<KnowledgeGraphNotifier, KnowledgeGraph>(
  KnowledgeGraphNotifier.new,
);

class KnowledgeGraphNotifier extends AsyncNotifier<KnowledgeGraph> {
  @override
  Future<KnowledgeGraph> build() async {
    final repo = ref.watch(graphRepositoryProvider);
    return repo.load();
  }

  Future<void> reload() async {
    final repo = ref.read(graphRepositoryProvider);
    state = const AsyncLoading();
    state = AsyncData(await repo.load());
  }

  Future<void> updateQuizItem(QuizItem updated) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final newGraph = current.withUpdatedQuizItem(updated);
    state = AsyncData(newGraph);

    final repo = ref.read(graphRepositoryProvider);
    await repo.updateQuizItem(newGraph, updated);
  }

  Future<void> ingestExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final newGraph = current.withNewExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
    );
    state = AsyncData(newGraph);

    final repo = ref.read(graphRepositoryProvider);
    await repo.save(newGraph);
  }

  void setGraph(KnowledgeGraph graph) {
    state = AsyncData(graph);
  }
}
