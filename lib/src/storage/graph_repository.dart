import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';

/// Abstract storage interface for the knowledge graph.
///
/// Implementations include [LocalGraphRepository] (JSON file) and
/// [FirestoreGraphRepository] (cloud sync).
abstract class GraphRepository {
  Future<KnowledgeGraph> load();

  Future<void> save(KnowledgeGraph graph);

  /// Update a single quiz item. Local impl delegates to [save];
  /// Firestore impl writes a single subcollection document.
  Future<void> updateQuizItem(KnowledgeGraph graph, QuizItem item) async {
    await save(graph);
  }

  /// Reactive stream of graph changes. Local impl emits once on load;
  /// Firestore impl emits on every snapshot change.
  Stream<KnowledgeGraph> watch();
}
