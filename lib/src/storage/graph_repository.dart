import '../models/concept.dart';
import '../models/document_metadata.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import '../models/topic.dart';

/// Storage interface for the knowledge graph.
///
/// Every write names the rows it changes. A row a write doesn't name keeps
/// its sync clock, so a change on another device to that row is never
/// overwritten by an unrelated write here, and nothing is deleted for being
/// absent from a caller's copy of the graph.
///
/// Implementations:
/// - [DriftGraphRepository] — local SQLite via Drift (primary store)
abstract class GraphRepository {
  Future<KnowledgeGraph> load();

  /// Writes [graph] into a store that has no rows yet, such as the first
  /// seed from Firestore. Throws [StateError] if the store has any rows.
  Future<void> seedEmpty(KnowledgeGraph graph);

  /// Writes one document's extraction: upserts its rows and tombstones the
  /// ids it dropped.
  Future<void> applyExtraction(ExtractionPatch patch);

  /// Writes a single quiz item, such as after a review.
  Future<void> updateQuizItem(QuizItem item);

  /// Writes the new entities from a concept split.
  Future<void> saveSplitData({
    required List<Concept> concepts,
    required List<Relationship> relationships,
    required List<QuizItem> quizItems,
  });

  /// Upserts [topics], each with exactly its `documentIds`.
  Future<void> upsertTopics(List<Topic> topics);

  /// Upserts document metadata rows, such as backfilled collection info.
  Future<void> upsertDocumentMetadata(List<DocumentMetadata> documents);

  /// Reactive stream of graph changes.
  Stream<KnowledgeGraph> watch();
}
