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

  /// Maximum size (in characters) of [ingestedText] to store. Documents
  /// larger than this are truncated to avoid bloating Firestore/local JSON.
  /// 100 KB of UTF-8 text is ~100K characters, well within Firestore's 1 MB
  /// document limit while leaving room for the rest of the graph.
  static const maxIngestedTextLength = 100000;

  final String documentId;
  final String title;
  final String updatedAt;
  final String ingestedAt;
  final String? collectionId;
  final String? collectionName;

  /// The document markdown text at the time of last ingestion.
  /// Used for diffing when the document is updated in the wiki.
  /// Truncated to [maxIngestedTextLength] characters to prevent storage bloat.
  final String? ingestedText;

  /// Truncate [text] to [maxIngestedTextLength] if it exceeds the limit.
  static String? capText(String? text) {
    if (text == null) return null;
    if (text.length <= maxIngestedTextLength) return text;
    return text.substring(0, maxIngestedTextLength);
  }

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
