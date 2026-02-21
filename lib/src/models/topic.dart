import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// A user-defined grouping of documents that scopes ingestion and enables
/// cross-document relationships within a knowledge graph.
@immutable
class Topic {
  Topic({
    required this.id,
    required this.name,
    this.description,
    Set<String> documentIds = const {},
    required this.createdAt,
    this.lastIngestedAt,
  }) : documentIds = ISet(documentIds);

  const Topic._raw({
    required this.id,
    required this.name,
    this.description,
    required this.documentIds,
    required this.createdAt,
    this.lastIngestedAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic._raw(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      documentIds:
          (json['documentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toISet() ??
          const ISetConst({}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastIngestedAt:
          json['lastIngestedAt'] != null
              ? DateTime.parse(json['lastIngestedAt'] as String)
              : null,
    );
  }

  final String id;
  final String name;
  final String? description;
  final ISet<String> documentIds;
  final DateTime createdAt;
  final DateTime? lastIngestedAt;

  Topic copyWith({
    String? id,
    String? name,
    String? Function()? description,
    ISet<String>? documentIds,
    DateTime? createdAt,
    DateTime? Function()? lastIngestedAt,
  }) {
    return Topic._raw(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description != null ? description() : this.description,
      documentIds: documentIds ?? this.documentIds,
      createdAt: createdAt ?? this.createdAt,
      lastIngestedAt:
          lastIngestedAt != null ? lastIngestedAt() : this.lastIngestedAt,
    );
  }

  Topic withDocumentIds(Set<String> documentIds) {
    return copyWith(documentIds: ISet(documentIds));
  }

  Topic withLastIngestedAt(DateTime lastIngestedAt) {
    return copyWith(lastIngestedAt: () => lastIngestedAt);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'documentIds': documentIds.toList(),
    'createdAt': createdAt.toIso8601String(),
    if (lastIngestedAt != null)
      'lastIngestedAt': lastIngestedAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Topic && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Topic($id: $name)';
}
