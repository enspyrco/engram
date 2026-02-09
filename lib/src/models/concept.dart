import 'package:meta/meta.dart';

@immutable
class Concept {
  const Concept({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceDocumentId,
    this.tags = const [],
  });

  factory Concept.fromJson(Map<String, dynamic> json) {
    return Concept(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      sourceDocumentId: json['sourceDocumentId'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  final String id;
  final String name;
  final String description;
  final String sourceDocumentId;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'sourceDocumentId': sourceDocumentId,
        'tags': tags,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Concept && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Concept withSourceDocumentId(String sourceDocumentId) {
    return Concept(
      id: id,
      name: name,
      description: description,
      sourceDocumentId: sourceDocumentId,
      tags: tags,
    );
  }

  @override
  String toString() => 'Concept($id: $name)';
}
