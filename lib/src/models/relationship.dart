import 'package:meta/meta.dart';

@immutable
class Relationship {
  const Relationship({
    required this.id,
    required this.fromConceptId,
    required this.toConceptId,
    required this.label,
    this.description,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    return Relationship(
      id: json['id'] as String,
      fromConceptId: json['fromConceptId'] as String,
      toConceptId: json['toConceptId'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String fromConceptId;
  final String toConceptId;
  final String label;
  final String? description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromConceptId': fromConceptId,
        'toConceptId': toConceptId,
        'label': label,
        if (description != null) 'description': description,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Relationship && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Relationship($fromConceptId --$label--> $toConceptId)';
}
