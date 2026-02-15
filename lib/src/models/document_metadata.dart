import 'package:meta/meta.dart';

@immutable
class DocumentMetadata {
  const DocumentMetadata({
    required this.documentId,
    required this.title,
    required this.updatedAt,
    required this.ingestedAt,
    this.collectionId,
    this.collectionName,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      documentId: json['documentId'] as String,
      title: json['title'] as String,
      updatedAt: json['updatedAt'] as String,
      ingestedAt: json['ingestedAt'] as String,
      collectionId: json['collectionId'] as String?,
      collectionName: json['collectionName'] as String?,
    );
  }

  final String documentId;
  final String title;
  final String updatedAt;
  final String ingestedAt;
  final String? collectionId;
  final String? collectionName;

  DocumentMetadata withUpdatedAt(String updatedAt, {DateTime? now}) {
    final currentTime = now ?? DateTime.now().toUtc();
    return DocumentMetadata(
      documentId: documentId,
      title: title,
      updatedAt: updatedAt,
      ingestedAt: currentTime.toIso8601String(),
      collectionId: collectionId,
      collectionName: collectionName,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'title': title,
        'updatedAt': updatedAt,
        'ingestedAt': ingestedAt,
        if (collectionId != null) 'collectionId': collectionId,
        if (collectionName != null) 'collectionName': collectionName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentMetadata && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;
}
