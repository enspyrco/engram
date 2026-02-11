import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'concept.dart';
import 'document_metadata.dart';
import 'quiz_item.dart';
import 'relationship.dart';

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
  })  : concepts = IList(concepts),
        relationships = IList(relationships),
        quizItems = IList(quizItems),
        documentMetadata = IList(documentMetadata);

  const KnowledgeGraph._raw({
    required this.concepts,
    required this.relationships,
    required this.quizItems,
    required this.documentMetadata,
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
    );
  }

  static final empty = KnowledgeGraph();

  final IList<Concept> concepts;
  final IList<Relationship> relationships;
  final IList<QuizItem> quizItems;
  final IList<DocumentMetadata> documentMetadata;

  /// Merge an extraction result into this graph, replacing data from the
  /// same document if it was previously ingested.
  KnowledgeGraph withNewExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    DateTime? now,
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

    // Update or add document metadata
    final currentTime = now ?? DateTime.now().toUtc();
    final existingIndex =
        documentMetadata.indexWhere((m) => m.documentId == documentId);
    final meta = DocumentMetadata(
      documentId: documentId,
      title: documentTitle,
      updatedAt: updatedAt,
      ingestedAt: currentTime.toIso8601String(),
    );
    final newMetadata = existingIndex >= 0
        ? documentMetadata.replace(existingIndex, meta)
        : documentMetadata.add(meta);

    return KnowledgeGraph._raw(
      concepts: newConcepts,
      relationships: newRelationships,
      quizItems: newQuizItems,
      documentMetadata: newMetadata,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'concepts': concepts.map((c) => c.toJson()).toList(),
        'relationships': relationships.map((r) => r.toJson()).toList(),
        'quizItems': quizItems.map((q) => q.toJson()).toList(),
        'documentMetadata': documentMetadata.map((m) => m.toJson()).toList(),
      };
}
