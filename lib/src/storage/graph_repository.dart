import '../models/concept.dart';
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
  /// seed from Firestore, and returns true. If the store has any row,
  /// tombstones included, writes nothing and returns false; the check and
  /// the write share one transaction.
  Future<bool> seedEmpty(KnowledgeGraph graph);

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

  /// Writes the changes from [previous], the caller's own prior copy of
  /// [topic]: its name and description if they differ, and exactly the
  /// document links added or removed. With no [previous] (a new topic) the
  /// whole topic is written. Anything the caller didn't change, such as a
  /// link or rename made on another device, is left alone.
  Future<void> upsertTopic(Topic topic, {Topic? previous});

  /// Records that [topicId] finished ingesting at [at], writing only that
  /// column of the topic row.
  Future<void> markTopicIngested(String topicId, DateTime at);

  /// Sets a document's collection, writing only the two collection columns
  /// of its row.
  Future<void> setDocumentCollection(
    String documentId, {
    required String collectionId,
    required String collectionName,
  });

  /// Reactive stream of graph changes.
  Stream<KnowledgeGraph> watch();
}
