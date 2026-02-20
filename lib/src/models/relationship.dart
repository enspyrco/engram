import 'package:meta/meta.dart';

/// The semantic type of a relationship between two concepts.
///
/// Each type has distinct visualization (color, stroke, arrows) and
/// some types drive dependency-aware unlocking in [GraphAnalyzer].
enum RelationshipType {
  /// A requires understanding B first. Drives concept unlocking.
  prerequisite,

  /// A is a subtype or specific instance of B.
  generalization,

  /// A is a component or part of B.
  composition,

  /// A makes B possible or practical (weaker than prerequisite).
  enables,

  /// Cross-discipline semantic similarity.
  analogy,

  /// Explicit difference between similar concepts.
  contrast,

  /// General association (catch-all).
  relatedTo;

  /// Whether this type represents a dependency edge for concept unlocking.
  bool get isDependency => this == prerequisite;

  /// Infer a [RelationshipType] from a legacy free-text label string.
  ///
  /// Used for backward compatibility with relationships that don't have
  /// an explicit `type` field stored in JSON/Firestore.
  static RelationshipType inferFromLabel(String label) {
    final lower = label.toLowerCase();
    if (['depends on', 'requires', 'prerequisite', 'builds on', 'assumes']
        .any((kw) => lower.contains(kw))) {
      return prerequisite;
    }
    if (lower.contains('type of')) return generalization;
    if (lower.contains('part of') || lower.contains('composed of')) {
      return composition;
    }
    if (lower.contains('enables')) return enables;
    if (lower.contains('analog')) return analogy;
    if (lower.contains('contrast')) return contrast;
    return relatedTo;
  }
}

@immutable
class Relationship {
  const Relationship({
    required this.id,
    required this.fromConceptId,
    required this.toConceptId,
    required this.label,
    this.description,
    this.type,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    final label = json['label'] as String;
    final typeStr = json['type'] as String?;
    return Relationship(
      id: json['id'] as String,
      fromConceptId: json['fromConceptId'] as String,
      toConceptId: json['toConceptId'] as String,
      label: label,
      description: json['description'] as String?,
      type: typeStr != null ? _parseType(typeStr) : null,
    );
  }

  final String id;
  final String fromConceptId;
  final String toConceptId;
  final String label;
  final String? description;

  /// Explicit relationship type, or `null` for legacy data.
  final RelationshipType? type;

  /// The effective type: explicit [type] if set, otherwise inferred from [label].
  RelationshipType get resolvedType =>
      type ?? RelationshipType.inferFromLabel(label);

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromConceptId': fromConceptId,
        'toConceptId': toConceptId,
        'label': label,
        if (description != null) 'description': description,
        'type': resolvedType.name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Relationship && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Relationship($fromConceptId --$label--> $toConceptId)';

  /// Parse a type string to [RelationshipType], with fallback to [relatedTo].
  static RelationshipType _parseType(String value) {
    for (final t in RelationshipType.values) {
      if (t.name == value) return t;
    }
    return RelationshipType.relatedTo;
  }
}
