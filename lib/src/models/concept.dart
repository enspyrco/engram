import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

@immutable
class Concept {
  Concept({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceDocumentId,
    List<String> tags = const [],
    this.parentConceptId,
  }) : tags = IList(tags);

  const Concept._raw({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceDocumentId,
    required this.tags,
    this.parentConceptId,
  });

  factory Concept.fromJson(Map<String, dynamic> json) {
    return Concept._raw(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      sourceDocumentId: json['sourceDocumentId'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toIList() ??
          const IListConst([]),
      parentConceptId: json['parentConceptId'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String sourceDocumentId;
  final IList<String> tags;
  final String? parentConceptId;

  bool get isSubConcept => parentConceptId != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sourceDocumentId': sourceDocumentId,
    'tags': tags.toList(),
    if (parentConceptId != null) 'parentConceptId': parentConceptId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Concept && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Concept withSourceDocumentId(String sourceDocumentId) {
    return Concept._raw(
      id: id,
      name: name,
      description: description,
      sourceDocumentId: sourceDocumentId,
      tags: tags,
      parentConceptId: parentConceptId,
    );
  }

  @override
  String toString() => 'Concept($id: $name)';
}
