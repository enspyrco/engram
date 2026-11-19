import 'package:drift/drift.dart';

import '../../models/concept.dart';
import '../../models/document_metadata.dart';
import '../../models/quiz_item.dart';
import '../../models/relationship.dart';
import '../../models/rubric.dart';
import '../../models/topic.dart';
import 'engram_database.dart';

// ---------------------------------------------------------------------------
// Concept ↔ DriftConcept
// ---------------------------------------------------------------------------

/// Maps a domain [Concept] to a Drift companion for insertion.
///
/// Pass [hlc] to stamp the row with a CRDT timestamp. If omitted, the
/// database default (empty string) is used. `embedding` is omitted
/// (reserved for #39).
extension ConceptToCompanion on Concept {
  DriftConceptsCompanion toCompanion({String hlc = ''}) {
    return DriftConceptsCompanion.insert(
      id: id,
      name: name,
      description: description,
      sourceDocumentId: sourceDocumentId,
      tags: tags,
      parentConceptId:
          parentConceptId != null
              ? Value(parentConceptId)
              : const Value.absent(),
      hlc: Value(hlc),
    );
  }
}

/// Maps a Drift row back to a domain [Concept].
///
/// `embedding` and `hlc` are storage-only columns and are not surfaced
/// in the domain model.
extension DriftConceptToDomain on DriftConcept {
  Concept toDomain() {
    return Concept(
      id: id,
      name: name,
      description: description,
      sourceDocumentId: sourceDocumentId,
      tags: tags.toList(),
      parentConceptId: parentConceptId,
    );
  }

  /// Produces a companion that preserves all columns including `hlc` and
  /// `isDeleted`. Used by [mergeChangeset] to re-insert incoming rows
  /// with their original HLC timestamps (not re-stamped).
  DriftConceptsCompanion toInsertCompanion() => DriftConceptsCompanion.insert(
    id: id,
    name: name,
    description: description,
    sourceDocumentId: sourceDocumentId,
    tags: tags,
    parentConceptId:
        parentConceptId != null ? Value(parentConceptId) : const Value.absent(),
    embedding: embedding != null ? Value(embedding) : const Value.absent(),
    hlc: Value(hlc),
    isDeleted: Value(isDeleted),
  );
}

// ---------------------------------------------------------------------------
// Relationship ↔ DriftRelationship
// ---------------------------------------------------------------------------

/// Maps a domain [Relationship] to a Drift companion for insertion.
///
/// Always stores [Relationship.resolvedType] (never null) — the DB column
/// is non-nullable, matching [Relationship.toJson] behaviour.
extension RelationshipToCompanion on Relationship {
  DriftRelationshipsCompanion toCompanion({String hlc = ''}) {
    return DriftRelationshipsCompanion.insert(
      id: id,
      fromConceptId: fromConceptId,
      toConceptId: toConceptId,
      label: label,
      description:
          description != null ? Value(description) : const Value.absent(),
      type: resolvedType,
      hlc: Value(hlc),
    );
  }
}

/// Maps a Drift row back to a domain [Relationship].
///
/// The `type` column is always populated in the database, so we pass it
/// through as an explicit type (not null).
extension DriftRelationshipToDomain on DriftRelationship {
  Relationship toDomain() {
    return Relationship(
      id: id,
      fromConceptId: fromConceptId,
      toConceptId: toConceptId,
      label: label,
      description: description,
      type: type,
    );
  }

  /// Produces a companion preserving all columns including `hlc` and
  /// `isDeleted` for CRDT merge.
  DriftRelationshipsCompanion toInsertCompanion() =>
      DriftRelationshipsCompanion.insert(
        id: id,
        fromConceptId: fromConceptId,
        toConceptId: toConceptId,
        label: label,
        description:
            description != null ? Value(description) : const Value.absent(),
        type: type,
        hlc: Value(hlc),
        isDeleted: Value(isDeleted),
      );
}

// ---------------------------------------------------------------------------
// QuizItem ↔ DriftQuizItem
// ---------------------------------------------------------------------------

/// Maps a domain [QuizItem] to a Drift companion for insertion.
///
/// DateTime fields are stored as ISO 8601 strings in the database because
/// Drift's TEXT columns handle them naturally and it keeps the schema simple
/// for CRDT sync (string comparison works for HLC timestamps too).
extension QuizItemToCompanion on QuizItem {
  DriftQuizItemsCompanion toCompanion({String hlc = ''}) {
    return DriftQuizItemsCompanion.insert(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      interval: interval,
      nextReview: nextReview.toIso8601String(),
      lastReview:
          lastReview != null
              ? Value(lastReview!.toIso8601String())
              : const Value.absent(),
      difficulty: difficulty != null ? Value(difficulty) : const Value.absent(),
      stability: stability != null ? Value(stability) : const Value.absent(),
      fsrsState: fsrsState != null ? Value(fsrsState) : const Value.absent(),
      lapses: lapses != null ? Value(lapses) : const Value.absent(),
      predictedDifficulty:
          predictedDifficulty != null
              ? Value(predictedDifficulty)
              : const Value.absent(),
      reviewCount: Value(reviewCount),
      rubric: Value(rubric?.criteria),
      hlc: Value(hlc),
    );
  }
}

/// Maps a Drift row back to a domain [QuizItem].
///
/// Constructs the [QuizItem] directly (not via `fromJson`) since Drift
/// data is already FSRS-ready — no auto-migration needed.
extension DriftQuizItemToDomain on DriftQuizItem {
  QuizItem toDomain() {
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      interval: interval,
      nextReview: DateTime.parse(nextReview),
      lastReview: lastReview != null ? DateTime.parse(lastReview!) : null,
      difficulty: difficulty,
      stability: stability,
      fsrsState: fsrsState,
      lapses: lapses,
      predictedDifficulty: predictedDifficulty,
      reviewCount: reviewCount,
      rubric: Rubric.parse(rubric?.unlock),
    );
  }

  /// Produces a companion preserving all columns including `hlc` and
  /// `isDeleted` for CRDT merge.
  DriftQuizItemsCompanion toInsertCompanion() => DriftQuizItemsCompanion.insert(
    id: id,
    conceptId: conceptId,
    question: question,
    answer: answer,
    interval: interval,
    nextReview: nextReview,
    lastReview: lastReview != null ? Value(lastReview) : const Value.absent(),
    difficulty: difficulty != null ? Value(difficulty) : const Value.absent(),
    stability: stability != null ? Value(stability) : const Value.absent(),
    fsrsState: fsrsState != null ? Value(fsrsState) : const Value.absent(),
    lapses: lapses != null ? Value(lapses) : const Value.absent(),
    predictedDifficulty:
        predictedDifficulty != null
            ? Value(predictedDifficulty)
            : const Value.absent(),
    reviewCount: Value(reviewCount),
    rubric: Value(rubric),
    hlc: Value(hlc),
    isDeleted: Value(isDeleted),
  );
}

// ---------------------------------------------------------------------------
// DocumentMetadata ↔ DriftDocument
// ---------------------------------------------------------------------------

/// Maps a domain [DocumentMetadata] to a Drift companion for insertion.
///
/// Note: [DocumentMetadata.updatedAt] is already a String (Outline API
/// passthrough), so it maps directly. [DocumentMetadata.ingestedAt] is a
/// DateTime that we convert to ISO 8601.
extension DocumentMetadataToCompanion on DocumentMetadata {
  DriftDocumentsCompanion toCompanion({String hlc = ''}) {
    return DriftDocumentsCompanion.insert(
      documentId: documentId,
      title: title,
      updatedAt: updatedAt,
      ingestedAt: ingestedAt.toIso8601String(),
      collectionId:
          collectionId != null ? Value(collectionId) : const Value.absent(),
      collectionName:
          collectionName != null ? Value(collectionName) : const Value.absent(),
      ingestedText:
          ingestedText != null ? Value(ingestedText) : const Value.absent(),
      hlc: Value(hlc),
    );
  }
}

/// Maps a Drift row back to a domain [DocumentMetadata].
extension DriftDocumentToDomain on DriftDocument {
  DocumentMetadata toDomain() {
    return DocumentMetadata(
      documentId: documentId,
      title: title,
      updatedAt: updatedAt,
      ingestedAt: DateTime.parse(ingestedAt),
      collectionId: collectionId,
      collectionName: collectionName,
      ingestedText: ingestedText,
    );
  }

  /// Produces a companion preserving all columns including `hlc` and
  /// `isDeleted` for CRDT merge.
  DriftDocumentsCompanion toInsertCompanion() => DriftDocumentsCompanion.insert(
    documentId: documentId,
    title: title,
    updatedAt: updatedAt,
    ingestedAt: ingestedAt,
    collectionId:
        collectionId != null ? Value(collectionId) : const Value.absent(),
    collectionName:
        collectionName != null ? Value(collectionName) : const Value.absent(),
    ingestedText:
        ingestedText != null ? Value(ingestedText) : const Value.absent(),
    hlc: Value(hlc),
    isDeleted: Value(isDeleted),
  );
}

// ---------------------------------------------------------------------------
// Topic ↔ DriftTopic + DriftTopicDocuments
// ---------------------------------------------------------------------------

/// Maps a domain [Topic] to a Drift companion for insertion.
///
/// Only produces the [DriftTopicsCompanion] — the caller is responsible for
/// creating [DriftTopicDocumentsCompanion] rows for each document ID in the
/// topic's [Topic.documentIds] set.
extension TopicToCompanion on Topic {
  DriftTopicsCompanion toCompanion({String hlc = ''}) {
    return DriftTopicsCompanion.insert(
      id: id,
      name: name,
      description:
          description != null ? Value(description) : const Value.absent(),
      createdAt: createdAt.toIso8601String(),
      lastIngestedAt:
          lastIngestedAt != null
              ? Value(lastIngestedAt!.toIso8601String())
              : const Value.absent(),
      hlc: Value(hlc),
    );
  }
}

/// Maps a Drift row back to a domain [Topic].
///
/// Requires [documentIds] to be passed in, since topic–document
/// relationships are stored in the separate [DriftTopicDocuments] join table.
extension DriftTopicToDomain on DriftTopic {
  Topic toDomain({required Set<String> documentIds}) {
    return Topic(
      id: id,
      name: name,
      description: description,
      documentIds: documentIds,
      createdAt: DateTime.parse(createdAt),
      lastIngestedAt:
          lastIngestedAt != null ? DateTime.parse(lastIngestedAt!) : null,
    );
  }

  /// Produces a companion preserving all columns including `hlc` and
  /// `isDeleted` for CRDT merge.
  DriftTopicsCompanion toInsertCompanion() => DriftTopicsCompanion.insert(
    id: id,
    name: name,
    description:
        description != null ? Value(description) : const Value.absent(),
    createdAt: createdAt,
    lastIngestedAt:
        lastIngestedAt != null ? Value(lastIngestedAt) : const Value.absent(),
    hlc: Value(hlc),
    isDeleted: Value(isDeleted),
  );
}

/// Produces a companion preserving all columns including `hlc` and
/// `isDeleted` for CRDT merge.
extension DriftTopicDocumentToInsertCompanion on DriftTopicDocument {
  DriftTopicDocumentsCompanion toInsertCompanion() =>
      DriftTopicDocumentsCompanion.insert(
        topicId: topicId,
        documentId: documentId,
        hlc: Value(hlc),
        isDeleted: Value(isDeleted),
      );
}
