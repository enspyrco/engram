import 'package:meta/meta.dart';

@immutable
class DocumentMetadata {
  const DocumentMetadata({
    required this.documentId,
    required this.title,
    required this.updatedAt,
    required this.ingestedAt,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      documentId: json['documentId'] as String,
      title: json['title'] as String,
      updatedAt: json['updatedAt'] as String,
      ingestedAt: json['ingestedAt'] as String,
    );
  }

  final String documentId;
  final String title;
  final String updatedAt;
  final String ingestedAt;

  DocumentMetadata withUpdatedAt(String updatedAt) {
    return DocumentMetadata(
      documentId: documentId,
      title: title,
      updatedAt: updatedAt,
      ingestedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'title': title,
        'updatedAt': updatedAt,
        'ingestedAt': ingestedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentMetadata && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;
}
