import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'knowledge_gap.dart';
import 'relationship.dart';

/// A predicted edge that would be created by ingesting a recommended document.
@immutable
class PredictedEdge {
  const PredictedEdge({
    required this.fromConceptName,
    required this.toConceptName,
    required this.type,
    required this.confidence,
  });

  factory PredictedEdge.fromJson(Map<String, dynamic> json) {
    return PredictedEdge(
      fromConceptName: json['fromConceptName'] as String,
      toConceptName: json['toConceptName'] as String,
      type:
          RelationshipType.tryParse(json['type'] as String) ??
          RelationshipType.relatedTo,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  /// Name of the source concept (may be new or existing).
  final String fromConceptName;

  /// Name of the target concept (may be new or existing).
  final String toConceptName;

  /// Predicted relationship type.
  final RelationshipType type;

  /// How confident Claude is in this prediction (0.0–1.0).
  final double confidence;

  Map<String, dynamic> toJson() => {
    'fromConceptName': fromConceptName,
    'toConceptName': toConceptName,
    'type': type.name,
    'confidence': confidence,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PredictedEdge &&
          other.fromConceptName == fromConceptName &&
          other.toConceptName == toConceptName &&
          other.type == type;

  @override
  int get hashCode => Object.hash(fromConceptName, toConceptName, type);
}

/// A recommended Outline document that could fill a knowledge gap.
///
/// Produced by [RecommendationService] after evaluating document–gap fit
/// with Claude. Consumed by the recommendations screen for user review.
@immutable
class Recommendation {
  Recommendation({
    required this.documentId,
    required this.documentTitle,
    required this.gap,
    required this.score,
    required this.reasoning,
    this.searchSnippet,
    this.collectionId,
    this.collectionName,
    List<PredictedEdge> predictedNewEdges = const [],
  }) : predictedNewEdges = IList(predictedNewEdges);

  const Recommendation._raw({
    required this.documentId,
    required this.documentTitle,
    required this.gap,
    required this.score,
    required this.reasoning,
    required this.predictedNewEdges,
    this.searchSnippet,
    this.collectionId,
    this.collectionName,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation._raw(
      documentId: json['documentId'] as String,
      documentTitle: json['documentTitle'] as String,
      gap: KnowledgeGap.fromJson(json['gap'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
      reasoning: json['reasoning'] as String,
      searchSnippet: json['searchSnippet'] as String?,
      collectionId: json['collectionId'] as String?,
      collectionName: json['collectionName'] as String?,
      predictedNewEdges:
          (json['predictedNewEdges'] as List<dynamic>?)
              ?.map((e) => PredictedEdge.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
    );
  }

  /// Outline document ID.
  final String documentId;

  /// Document title for display.
  final String documentTitle;

  /// The knowledge gap this recommendation addresses.
  final KnowledgeGap gap;

  /// How well this document fills the gap (0.0–1.0).
  final double score;

  /// Claude's reasoning for the recommendation.
  final String reasoning;

  /// Edges that would likely be created by ingesting this document.
  final IList<PredictedEdge> predictedNewEdges;

  /// Context snippet from the Outline search result.
  final String? searchSnippet;

  /// Collection the document belongs to.
  final String? collectionId;

  /// Collection name for display.
  final String? collectionName;

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'documentTitle': documentTitle,
    'gap': gap.toJson(),
    'score': score,
    'reasoning': reasoning,
    'predictedNewEdges': predictedNewEdges.map((e) => e.toJson()).toList(),
    if (searchSnippet != null) 'searchSnippet': searchSnippet,
    if (collectionId != null) 'collectionId': collectionId,
    if (collectionName != null) 'collectionName': collectionName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recommendation && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;

  @override
  String toString() =>
      'Recommendation("$documentTitle", score: $score, '
      'edges: ${predictedNewEdges.length})';
}
