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
  const KnowledgeGraph({
    this.concepts = const [],
    this.relationships = const [],
    this.quizItems = const [],
    this.documentMetadata = const [],
  });

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) {
    return KnowledgeGraph(
      concepts: (json['concepts'] as List<dynamic>?)
              ?.map((e) => Concept.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      relationships: (json['relationships'] as List<dynamic>?)
              ?.map((e) => Relationship.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      quizItems: (json['quizItems'] as List<dynamic>?)
              ?.map((e) => QuizItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      documentMetadata: (json['documentMetadata'] as List<dynamic>?)
              ?.map(
                  (e) => DocumentMetadata.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  static const empty = KnowledgeGraph();

  final List<Concept> concepts;
  final List<Relationship> relationships;
  final List<QuizItem> quizItems;
  final List<DocumentMetadata> documentMetadata;

  /// Merge an extraction result into this graph, replacing data from the
  /// same document if it was previously ingested.
  KnowledgeGraph withNewExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
  }) {
    // Remove old data from the same document
    final oldConceptIds = concepts
        .where((c) => c.sourceDocumentId == documentId)
        .map((c) => c.id)
        .toSet();

    final newConcepts = [
      ...concepts.where((c) => c.sourceDocumentId != documentId),
      ...result.concepts.map((c) => c.withSourceDocumentId(documentId)),
    ];

    final newRelationships = [
      // Keep relationships not referencing old concepts from this doc
      ...relationships.where((r) =>
          !oldConceptIds.contains(r.fromConceptId) &&
          !oldConceptIds.contains(r.toConceptId)),
      ...result.relationships,
    ];

    final newQuizItems = [
      // Keep quiz items not referencing old concepts from this doc
      ...quizItems.where((q) => !oldConceptIds.contains(q.conceptId)),
      ...result.quizItems,
    ];

    // Update or add document metadata
    final existingIndex =
        documentMetadata.indexWhere((m) => m.documentId == documentId);
    final meta = DocumentMetadata(
      documentId: documentId,
      title: documentTitle,
      updatedAt: updatedAt,
      ingestedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final newMetadata = [...documentMetadata];
    if (existingIndex >= 0) {
      newMetadata[existingIndex] = meta;
    } else {
      newMetadata.add(meta);
    }

    return KnowledgeGraph(
      concepts: newConcepts,
      relationships: newRelationships,
      quizItems: newQuizItems,
      documentMetadata: newMetadata,
    );
  }

  /// Return a new graph with one quiz item replaced.
  KnowledgeGraph withUpdatedQuizItem(QuizItem updated) {
    return KnowledgeGraph(
      concepts: concepts,
      relationships: relationships,
      quizItems: [
        for (final item in quizItems)
          if (item.id == updated.id) updated else item,
      ],
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
