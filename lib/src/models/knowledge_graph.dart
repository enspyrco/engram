import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'concept.dart';
import 'document_metadata.dart';
import 'quiz_item.dart';
import 'relationship.dart';
import 'topic.dart';

/// Result from a single document extraction.
class ExtractionResult {
  const ExtractionResult({
    required this.concepts,
    required this.relationships,
    required this.quizItems,
  });

  final List<Concept> concepts;
  final List<Relationship> relationships;
  final List<QuizItem> quizItems;
}

@immutable
class KnowledgeGraph {
  KnowledgeGraph({
    List<Concept> concepts = const [],
    List<Relationship> relationships = const [],
    List<QuizItem> quizItems = const [],
    List<DocumentMetadata> documentMetadata = const [],
    List<Topic> topics = const [],
  })  : concepts = IList(concepts),
        relationships = IList(relationships),
        quizItems = IList(quizItems),
        documentMetadata = IList(documentMetadata),
        topics = IList(topics);

  const KnowledgeGraph._raw({
    required this.concepts,
    required this.relationships,
    required this.quizItems,
    required this.documentMetadata,
    required this.topics,
  });

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) {
    return KnowledgeGraph._raw(
      concepts: (json['concepts'] as List<dynamic>?)
              ?.map((e) => Concept.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
      relationships: (json['relationships'] as List<dynamic>?)
              ?.map((e) => Relationship.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
      quizItems: (json['quizItems'] as List<dynamic>?)
              ?.map((e) => QuizItem.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
      documentMetadata: (json['documentMetadata'] as List<dynamic>?)
              ?.map(
                  (e) => DocumentMetadata.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => Topic.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
    );
  }

  static final empty = KnowledgeGraph();

  final IList<Concept> concepts;
  final IList<Relationship> relationships;
  final IList<QuizItem> quizItems;
  final IList<DocumentMetadata> documentMetadata;
  final IList<Topic> topics;

  /// Merge an extraction result into this graph, replacing data from the
  /// same document if it was previously ingested.
  KnowledgeGraph withNewExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    DateTime? now,
    String? collectionId,
    String? collectionName,
    String? documentText,
  }) {
    // Remove old data from the same document
    final oldConceptIds = concepts
        .where((c) => c.sourceDocumentId == documentId)
        .map((c) => c.id)
        .toSet();

    final newConcepts = [
      ...concepts.where((c) => c.sourceDocumentId != documentId),
      ...result.concepts.map((c) => c.withSourceDocumentId(documentId)),
    ].lock;

    final newRelationships = [
      // Keep relationships not referencing old concepts from this doc
      ...relationships.where((r) =>
          !oldConceptIds.contains(r.fromConceptId) &&
          !oldConceptIds.contains(r.toConceptId)),
      ...result.relationships,
    ].lock;

    final newQuizItems = [
      // Keep quiz items not referencing old concepts from this doc
      ...quizItems.where((q) => !oldConceptIds.contains(q.conceptId)),
      ...result.quizItems,
    ].lock;

    // Update or add document metadata — preserve existing collection info
    // if new values are not supplied (e.g. during sync re-ingestion).
    final currentTime = now ?? DateTime.now().toUtc();
    final existingIndex =
        documentMetadata.indexWhere((m) => m.documentId == documentId);
    final existing =
        existingIndex >= 0 ? documentMetadata[existingIndex] : null;
    final meta = DocumentMetadata(
      documentId: documentId,
      title: documentTitle,
      updatedAt: updatedAt,
      ingestedAt: currentTime.toIso8601String(),
      collectionId: collectionId ?? existing?.collectionId,
      collectionName: collectionName ?? existing?.collectionName,
      ingestedText: documentText ?? existing?.ingestedText,
    );
    final newMetadata = existingIndex >= 0
        ? documentMetadata.replace(existingIndex, meta)
        : documentMetadata.add(meta);

    return KnowledgeGraph._raw(
      concepts: newConcepts,
      relationships: newRelationships,
      quizItems: newQuizItems,
      documentMetadata: newMetadata,
      topics: topics,
    );
  }

  /// Backfill collection info on an existing document's metadata.
  /// Returns `this` unchanged if the document is not found or already has
  /// collection info.
  KnowledgeGraph withDocumentCollectionInfo(
    String documentId, {
    required String collectionId,
    required String collectionName,
  }) {
    final idx = documentMetadata.indexWhere((m) => m.documentId == documentId);
    if (idx < 0) return this;
    final existing = documentMetadata[idx];
    if (existing.collectionId != null) return this;
    final updated = DocumentMetadata(
      documentId: existing.documentId,
      title: existing.title,
      updatedAt: existing.updatedAt,
      ingestedAt: existing.ingestedAt,
      collectionId: collectionId,
      collectionName: collectionName,
    );
    return KnowledgeGraph._raw(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems,
      documentMetadata: documentMetadata.replace(idx, updated),
      topics: topics,
    );
  }

  /// Return a new graph with one quiz item replaced.
  KnowledgeGraph withUpdatedQuizItem(QuizItem updated) {
    final idx = quizItems.indexWhere((item) => item.id == updated.id);
    if (idx < 0) return this;
    return KnowledgeGraph._raw(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems.replace(idx, updated),
      documentMetadata: documentMetadata,
      topics: topics,
    );
  }

  /// Add child concepts from a split operation. Purely additive — the parent
  /// concept remains, children are added with "is part of" relationships,
  /// and new quiz items are created for each child.
  KnowledgeGraph withConceptSplit({
    required List<Concept> children,
    required List<Relationship> childRelationships,
    required List<QuizItem> childQuizItems,
  }) {
    return KnowledgeGraph._raw(
      concepts: concepts.addAll(children),
      relationships: relationships.addAll(childRelationships),
      quizItems: quizItems.addAll(childQuizItems),
      documentMetadata: documentMetadata,
      topics: topics,
    );
  }

  /// Upsert a topic by ID. If a topic with the same ID exists, it is replaced.
  KnowledgeGraph withTopic(Topic topic) {
    final idx = topics.indexWhere((t) => t.id == topic.id);
    final newTopics = idx >= 0 ? topics.replace(idx, topic) : topics.add(topic);
    return KnowledgeGraph._raw(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems,
      documentMetadata: documentMetadata,
      topics: newTopics,
    );
  }

  /// Remove a topic by ID.
  KnowledgeGraph withoutTopic(String topicId) {
    return KnowledgeGraph._raw(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems,
      documentMetadata: documentMetadata,
      topics: topics.removeWhere((t) => t.id == topicId),
    );
  }

  Map<String, dynamic> toJson() => {
        'concepts': concepts.map((c) => c.toJson()).toList(),
        'relationships': relationships.map((r) => r.toJson()).toList(),
        'quizItems': quizItems.map((q) => q.toJson()).toList(),
        'documentMetadata': documentMetadata.map((m) => m.toJson()).toList(),
        'topics': topics.map((t) => t.toJson()).toList(),
      };
}
