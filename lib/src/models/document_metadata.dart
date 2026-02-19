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
    this.ingestedText,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      documentId: json['documentId'] as String,
      title: json['title'] as String,
      updatedAt: json['updatedAt'] as String,
      ingestedAt: json['ingestedAt'] as String,
      collectionId: json['collectionId'] as String?,
      collectionName: json['collectionName'] as String?,
      ingestedText: json['ingestedText'] as String?,
    );
  }

  final String documentId;
  final String title;
  final String updatedAt;
  final String ingestedAt;
  final String? collectionId;
  final String? collectionName;

  /// The document markdown text at the time of last ingestion.
  /// Used for diffing when the document is updated in the wiki.
  final String? ingestedText;

  DocumentMetadata withUpdatedAt(
    String updatedAt, {
    DateTime? now,
    String? ingestedText,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();
    return DocumentMetadata(
      documentId: documentId,
      title: title,
      updatedAt: updatedAt,
      ingestedAt: currentTime.toIso8601String(),
      collectionId: collectionId,
      collectionName: collectionName,
      ingestedText: ingestedText ?? this.ingestedText,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'title': title,
        'updatedAt': updatedAt,
        'ingestedAt': ingestedAt,
        if (collectionId != null) 'collectionId': collectionId,
        if (collectionName != null) 'collectionName': collectionName,
        if (ingestedText != null) 'ingestedText': ingestedText,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentMetadata && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;
}
