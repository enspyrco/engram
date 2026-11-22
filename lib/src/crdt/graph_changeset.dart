import 'dart:convert';

import '../models/rubric.dart';
import '../storage/drift/engram_database.dart';
import '../storage/drift/type_converters.dart';

/// A typed changeset containing modified rows across all knowledge graph tables.
///
/// Used by the CRDT sync layer to exchange changes between replicas. Each
/// device generates a changeset of rows modified since a given HLC, and
/// merges incoming changesets using last-write-wins per row.
///
/// Internally uses Drift data classes for type safety. Serializes to/from
/// `Map<String, List<Map<String, Object?>>>` (table name → list of column
/// maps) for wire transport — compatible with `package:crdt`'s
/// `CrdtChangeset` typedef.
class GraphChangeset {
  const GraphChangeset({
    this.concepts = const [],
    this.relationships = const [],
    this.quizItems = const [],
    this.documents = const [],
    this.topics = const [],
    this.topicDocuments = const [],
  });

  /// Deserializes from wire format.
  ///
  /// Missing table keys are treated as empty lists (partial changesets are
  /// valid — a device may only have changes in some tables).
  factory GraphChangeset.fromJson(Map<String, dynamic> json) {
    return GraphChangeset(
      concepts: _parseList(json['drift_concepts'], _conceptFromJson),
      relationships: _parseList(
        json['drift_relationships'],
        _relationshipFromJson,
      ),
      quizItems: _parseList(json['drift_quiz_items'], _quizItemFromJson),
      documents: _parseList(json['drift_documents'], _documentFromJson),
      topics: _parseList(json['drift_topics'], _topicFromJson),
      topicDocuments: _parseList(
        json['drift_topic_documents'],
        _topicDocumentFromJson,
      ),
    );
  }

  final List<DriftConcept> concepts;
  final List<DriftRelationship> relationships;
  final List<DriftQuizItem> quizItems;
  final List<DriftDocument> documents;
  final List<DriftTopic> topics;
  final List<DriftTopicDocument> topicDocuments;

  /// Whether the changeset contains no rows at all.
  bool get isEmpty =>
      concepts.isEmpty &&
      relationships.isEmpty &&
      quizItems.isEmpty &&
      documents.isEmpty &&
      topics.isEmpty &&
      topicDocuments.isEmpty;

  /// Total number of rows across all tables.
  int get recordCount =>
      concepts.length +
      relationships.length +
      quizItems.length +
      documents.length +
      topics.length +
      topicDocuments.length;

  /// The lexicographically highest HLC across all rows, or empty string if
  /// the changeset is empty.
  ///
  /// Becomes the push bookmark once pushed: every later local write carries
  /// a higher clock. Not a log position, since a late push carries old
  /// clocks.
  String get maxHlc {
    if (isEmpty) return '';

    var best = '';
    for (final c in concepts) {
      if (c.hlc.compareTo(best) > 0) best = c.hlc;
    }
    for (final r in relationships) {
      if (r.hlc.compareTo(best) > 0) best = r.hlc;
    }
    for (final q in quizItems) {
      if (q.hlc.compareTo(best) > 0) best = q.hlc;
    }
    for (final d in documents) {
      if (d.hlc.compareTo(best) > 0) best = d.hlc;
    }
    for (final t in topics) {
      if (t.hlc.compareTo(best) > 0) best = t.hlc;
    }
    for (final td in topicDocuments) {
      if (td.hlc.compareTo(best) > 0) best = td.hlc;
    }
    return best;
  }

  /// Serializes to wire format using SQL column names.
  ///
  /// TypeConverter columns (`tags`, `type`, `rubric`) are serialized through their
  /// `toSql()` methods so the wire format uses raw SQL values.
  Map<String, List<Map<String, Object?>>> toJson() {
    return {
      if (concepts.isNotEmpty)
        'drift_concepts': concepts.map(_conceptToJson).toList(),
      if (relationships.isNotEmpty)
        'drift_relationships': relationships.map(_relationshipToJson).toList(),
      if (quizItems.isNotEmpty)
        'drift_quiz_items': quizItems.map(_quizItemToJson).toList(),
      if (documents.isNotEmpty)
        'drift_documents': documents.map(_documentToJson).toList(),
      if (topics.isNotEmpty) 'drift_topics': topics.map(_topicToJson).toList(),
      if (topicDocuments.isNotEmpty)
        'drift_topic_documents':
            topicDocuments.map(_topicDocumentToJson).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers — Drift data class → JSON map (SQL column names)
  // ---------------------------------------------------------------------------

  static const _tagsConverter = IListStringConverter();
  static const _rubricConverter = IListStringConverter();
  static const _typeConverter = RelationshipTypeConverter();

  static Map<String, Object?> _conceptToJson(DriftConcept c) => {
    'id': c.id,
    'name': c.name,
    'description': c.description,
    'source_document_id': c.sourceDocumentId,
    'tags': _tagsConverter.toSql(c.tags),
    'parent_concept_id': c.parentConceptId,
    'embedding': c.embedding != null ? base64Encode(c.embedding!) : null,
    'hlc': c.hlc,
    'is_deleted': c.isDeleted ? 1 : 0,
  };

  static Map<String, Object?> _relationshipToJson(DriftRelationship r) => {
    'id': r.id,
    'from_concept_id': r.fromConceptId,
    'to_concept_id': r.toConceptId,
    'label': r.label,
    'description': r.description,
    'type': _typeConverter.toSql(r.type),
    'hlc': r.hlc,
    'is_deleted': r.isDeleted ? 1 : 0,
  };

  static Map<String, Object?> _quizItemToJson(DriftQuizItem q) => {
    'id': q.id,
    'concept_id': q.conceptId,
    'question': q.question,
    'answer': q.answer,
    'interval': q.interval,
    'next_review': q.nextReview,
    'last_review': q.lastReview,
    'difficulty': q.difficulty,
    'stability': q.stability,
    'fsrs_state': q.fsrsState,
    'lapses': q.lapses,
    'predicted_difficulty': q.predictedDifficulty,
    'review_count': q.reviewCount,
    'rubric': switch (q.rubric) {
      final rubric? => _rubricConverter.toSql(rubric),
      null => null,
    },
    'hlc': q.hlc,
    'is_deleted': q.isDeleted ? 1 : 0,
  };

  static Map<String, Object?> _documentToJson(DriftDocument d) => {
    'document_id': d.documentId,
    'title': d.title,
    'updated_at': d.updatedAt,
    'ingested_at': d.ingestedAt,
    'collection_id': d.collectionId,
    'collection_name': d.collectionName,
    'ingested_text': d.ingestedText,
    'hlc': d.hlc,
    'is_deleted': d.isDeleted ? 1 : 0,
  };

  static Map<String, Object?> _topicToJson(DriftTopic t) => {
    'id': t.id,
    'name': t.name,
    'description': t.description,
    'created_at': t.createdAt,
    'last_ingested_at': t.lastIngestedAt,
    'hlc': t.hlc,
    'is_deleted': t.isDeleted ? 1 : 0,
  };

  static Map<String, Object?> _topicDocumentToJson(DriftTopicDocument td) => {
    'topic_id': td.topicId,
    'document_id': td.documentId,
    'hlc': td.hlc,
    'is_deleted': td.isDeleted ? 1 : 0,
  };

  // ---------------------------------------------------------------------------
  // Deserialization helpers — JSON map → Drift data class
  // ---------------------------------------------------------------------------

  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (raw == null) return const [];
    final list = raw as List<dynamic>;
    return list.map((e) => parser(e as Map<String, dynamic>)).toList();
  }

  static DriftConcept _conceptFromJson(Map<String, dynamic> m) {
    return DriftConcept(
      id: m['id'] as String,
      name: m['name'] as String,
      description: m['description'] as String,
      sourceDocumentId: m['source_document_id'] as String,
      tags: _tagsConverter.fromSql(m['tags'] as String),
      parentConceptId: m['parent_concept_id'] as String?,
      embedding:
          m['embedding'] != null
              ? base64Decode(m['embedding'] as String)
              : null,
      hlc: m['hlc'] as String,
      isDeleted: _parseBool(m['is_deleted']),
    );
  }

  static DriftRelationship _relationshipFromJson(Map<String, dynamic> m) {
    return DriftRelationship(
      id: m['id'] as String,
      fromConceptId: m['from_concept_id'] as String,
      toConceptId: m['to_concept_id'] as String,
      label: m['label'] as String,
      description: m['description'] as String?,
      type: _typeConverter.fromSql(m['type'] as String),
      hlc: m['hlc'] as String,
      isDeleted: _parseBool(m['is_deleted']),
    );
  }

  static DriftQuizItem _quizItemFromJson(Map<String, dynamic> m) {
    return DriftQuizItem(
      id: m['id'] as String,
      conceptId: m['concept_id'] as String,
      question: m['question'] as String,
      answer: m['answer'] as String,
      interval: m['interval'] as int,
      nextReview: m['next_review'] as String,
      lastReview: m['last_review'] as String?,
      difficulty: (m['difficulty'] as num?)?.toDouble(),
      stability: (m['stability'] as num?)?.toDouble(),
      fsrsState: m['fsrs_state'] as int?,
      lapses: m['lapses'] as int?,
      predictedDifficulty: (m['predicted_difficulty'] as num?)?.toDouble(),
      reviewCount: m['review_count'] as int,
      // A peer's rubric is validated here, so the column only ever holds a
      // canonical Rubric or NULL.
      rubric: switch (m['rubric']) {
        final String sql => Rubric.parseJsonText(sql)?.criteria,
        _ => null,
      },
      hlc: m['hlc'] as String,
      isDeleted: _parseBool(m['is_deleted']),
    );
  }

  static DriftDocument _documentFromJson(Map<String, dynamic> m) {
    return DriftDocument(
      documentId: m['document_id'] as String,
      title: m['title'] as String,
      updatedAt: m['updated_at'] as String,
      ingestedAt: m['ingested_at'] as String,
      collectionId: m['collection_id'] as String?,
      collectionName: m['collection_name'] as String?,
      ingestedText: m['ingested_text'] as String?,
      hlc: m['hlc'] as String,
      isDeleted: _parseBool(m['is_deleted']),
    );
  }

  static DriftTopic _topicFromJson(Map<String, dynamic> m) {
    return DriftTopic(
      id: m['id'] as String,
      name: m['name'] as String,
      description: m['description'] as String?,
      createdAt: m['created_at'] as String,
      lastIngestedAt: m['last_ingested_at'] as String?,
      hlc: m['hlc'] as String,
      isDeleted: _parseBool(m['is_deleted']),
    );
  }

  static DriftTopicDocument _topicDocumentFromJson(Map<String, dynamic> m) {
    return DriftTopicDocument(
      topicId: m['topic_id'] as String,
      documentId: m['document_id'] as String,
      hlc: m['hlc'] as String,
      isDeleted: _parseBool(m['is_deleted']),
    );
  }

  /// Parses a boolean that might be encoded as int (SQLite) or bool (JSON).
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    return false;
  }
}
