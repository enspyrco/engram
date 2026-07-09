import 'package:drift/native.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/models/topic.dart';
import 'package:engram/src/storage/drift/drift_mappers.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

import '../../helpers/quiz_item_helpers.dart';

/// Round-trip tests: domain → toCompanion() → DB insert → DB select → toDomain() → verify equality.
///
/// Each test inserts via the mapper companion, reads back the Drift data class,
/// and converts back to the domain model to verify nothing is lost.
void main() {
  late EngramDatabase db;

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Concept mapper', () {
    test('round-trips all fields including parentConceptId', () async {
      final concept = Concept(
        id: 'c1',
        name: 'Docker',
        description: 'Container runtime',
        sourceDocumentId: 'doc1',
        tags: const ['devops', 'containers'],
        parentConceptId: 'parent1',
      );

      await db.into(db.driftConcepts).insert(concept.toCompanion());
      final row = await db.select(db.driftConcepts).getSingle();
      final result = row.toDomain();

      expect(result.id, concept.id);
      expect(result.name, concept.name);
      expect(result.description, concept.description);
      expect(result.sourceDocumentId, concept.sourceDocumentId);
      expect(result.tags, concept.tags);
      expect(result.parentConceptId, 'parent1');
      expect(result.isSubConcept, isTrue);
    });

    test('round-trips with null parentConceptId', () async {
      final concept = Concept(
        id: 'c2',
        name: 'Kubernetes',
        description: 'Container orchestration',
        sourceDocumentId: 'doc1',
      );

      await db.into(db.driftConcepts).insert(concept.toCompanion());
      final row = await db.select(db.driftConcepts).getSingle();
      final result = row.toDomain();

      expect(result.parentConceptId, isNull);
      expect(result.isSubConcept, isFalse);
    });

    test('round-trips with empty tags', () async {
      final concept = Concept(
        id: 'c3',
        name: 'Helm',
        description: 'Package manager',
        sourceDocumentId: 'doc1',
      );

      await db.into(db.driftConcepts).insert(concept.toCompanion());
      final row = await db.select(db.driftConcepts).getSingle();
      final result = row.toDomain();

      expect(result.tags, isEmpty);
    });

    test('omits embedding and hlc (uses DB defaults)', () async {
      final concept = Concept(
        id: 'c4',
        name: 'Test',
        description: 'Test',
        sourceDocumentId: 'doc1',
      );

      await db.into(db.driftConcepts).insert(concept.toCompanion());
      final row = await db.select(db.driftConcepts).getSingle();

      // DB defaults
      expect(row.embedding, isNull);
      expect(row.hlc, '');
    });
  });

  group('Relationship mapper', () {
    test('round-trips all fields with explicit type', () async {
      const relationship = Relationship(
        id: 'r1',
        fromConceptId: 'c1',
        toConceptId: 'c2',
        label: 'depends on',
        description: 'Docker depends on Linux namespaces',
        type: RelationshipType.prerequisite,
      );

      await db.into(db.driftRelationships).insert(relationship.toCompanion());
      final row = await db.select(db.driftRelationships).getSingle();
      final result = row.toDomain();

      expect(result.id, relationship.id);
      expect(result.fromConceptId, relationship.fromConceptId);
      expect(result.toConceptId, relationship.toConceptId);
      expect(result.label, relationship.label);
      expect(result.description, relationship.description);
      expect(result.type, RelationshipType.prerequisite);
    });

    test('stores resolvedType for null type (inferred from label)', () async {
      const relationship = Relationship(
        id: 'r2',
        fromConceptId: 'c1',
        toConceptId: 'c2',
        label: 'depends on',
        // type is null — legacy data
      );

      // resolvedType should infer 'prerequisite' from label
      expect(relationship.resolvedType, RelationshipType.prerequisite);

      await db.into(db.driftRelationships).insert(relationship.toCompanion());
      final row = await db.select(db.driftRelationships).getSingle();
      final result = row.toDomain();

      // After round-trip, type is explicitly stored as prerequisite
      expect(result.type, RelationshipType.prerequisite);
    });

    test('round-trips with null description', () async {
      const relationship = Relationship(
        id: 'r3',
        fromConceptId: 'c1',
        toConceptId: 'c2',
        label: 'related',
        type: RelationshipType.relatedTo,
      );

      await db.into(db.driftRelationships).insert(relationship.toCompanion());
      final row = await db.select(db.driftRelationships).getSingle();
      final result = row.toDomain();

      expect(result.description, isNull);
    });
  });

  group('QuizItem mapper', () {
    test('round-trips full FSRS state', () async {
      final item = testQuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is Docker?',
        answer: 'A container runtime',
        interval: 5,
        nextReview: DateTime.utc(2026, 3, 1),
        lastReview: DateTime.utc(2026, 2, 24),
        difficulty: 4.2,
        stability: 12.5,
        fsrsState: 2,
        lapses: 1,
        predictedDifficulty: 3.8,
        reviewCount: 7,
      );

      await db.into(db.driftQuizItems).insert(item.toCompanion());
      final row = await db.select(db.driftQuizItems).getSingle();
      final result = row.toDomain();

      expect(result.id, item.id);
      expect(result.conceptId, item.conceptId);
      expect(result.question, item.question);
      expect(result.answer, item.answer);
      expect(result.interval, item.interval);
      expect(result.nextReview, item.nextReview);
      expect(result.lastReview, item.lastReview);
      expect(result.difficulty, item.difficulty);
      expect(result.stability, item.stability);
      expect(result.fsrsState, item.fsrsState);
      expect(result.lapses, item.lapses);
      expect(result.predictedDifficulty, item.predictedDifficulty);
      expect(result.reviewCount, item.reviewCount);
    });

    test('round-trips with null FSRS fields', () async {
      final item = QuizItem(
        id: 'q2',
        conceptId: 'c1',
        question: 'What is a pod?',
        answer: 'Smallest deployable unit in Kubernetes',
        interval: 0,
        nextReview: DateTime.utc(2026, 2, 20),
        lastReview: null,
        difficulty: null,
        stability: null,
        fsrsState: null,
        lapses: null,
        predictedDifficulty: null,
      );

      await db.into(db.driftQuizItems).insert(item.toCompanion());
      final row = await db.select(db.driftQuizItems).getSingle();
      final result = row.toDomain();

      expect(result.lastReview, isNull);
      expect(result.difficulty, isNull);
      expect(result.stability, isNull);
      expect(result.fsrsState, isNull);
      expect(result.lapses, isNull);
      expect(result.predictedDifficulty, isNull);
      expect(result.reviewCount, 0);
    });

    test('preserves DateTime precision through ISO 8601', () async {
      final now = DateTime.utc(2026, 2, 24, 15, 30, 45, 123);
      final item = testQuizItem(
        nextReview: now,
        lastReview: now.subtract(const Duration(days: 3)),
      );

      await db.into(db.driftQuizItems).insert(item.toCompanion());
      final row = await db.select(db.driftQuizItems).getSingle();
      final result = row.toDomain();

      expect(result.nextReview, now);
      expect(result.lastReview, now.subtract(const Duration(days: 3)));
    });

    test('round-trips rubric through the Drift column', () async {
      final item = testQuizItem(
        rubric: const ['names both terms', 'explains the mechanism'].lock,
      );

      await db.into(db.driftQuizItems).insert(item.toCompanion());
      final row = await db.select(db.driftQuizItems).getSingle();
      final result = row.toDomain();

      expect(result.rubric?.unlock, [
        'names both terms',
        'explains the mechanism',
      ]);
    });

    test('null rubric round-trips as null', () async {
      final item = testQuizItem();

      await db.into(db.driftQuizItems).insert(item.toCompanion());
      final row = await db.select(db.driftQuizItems).getSingle();
      final result = row.toDomain();

      expect(result.rubric, isNull);
    });
  });

  group('DocumentMetadata mapper', () {
    test('round-trips all fields', () async {
      final doc = DocumentMetadata(
        documentId: 'doc1',
        title: 'Docker Guide',
        updatedAt: '2026-02-20T10:00:00.000Z',
        ingestedAt: DateTime.utc(2026, 2, 24),
        collectionId: 'col1',
        collectionName: 'DevOps',
        ingestedText: 'Docker is a container runtime...',
      );

      await db.into(db.driftDocuments).insert(doc.toCompanion());
      final row = await db.select(db.driftDocuments).getSingle();
      final result = row.toDomain();

      expect(result.documentId, doc.documentId);
      expect(result.title, doc.title);
      expect(result.updatedAt, doc.updatedAt);
      expect(result.ingestedAt, doc.ingestedAt);
      expect(result.collectionId, doc.collectionId);
      expect(result.collectionName, doc.collectionName);
      expect(result.ingestedText, doc.ingestedText);
    });

    test('round-trips with null optional fields', () async {
      final doc = DocumentMetadata(
        documentId: 'doc2',
        title: 'Kubernetes Basics',
        updatedAt: '2026-01-15T08:00:00.000Z',
        ingestedAt: DateTime.utc(2026, 1, 20),
      );

      await db.into(db.driftDocuments).insert(doc.toCompanion());
      final row = await db.select(db.driftDocuments).getSingle();
      final result = row.toDomain();

      expect(result.collectionId, isNull);
      expect(result.collectionName, isNull);
      expect(result.ingestedText, isNull);
    });

    test('updatedAt stays as String (Outline API passthrough)', () async {
      const outlineTimestamp = '2026-02-20T10:00:00.000Z';
      final doc = DocumentMetadata(
        documentId: 'doc3',
        title: 'Test',
        updatedAt: outlineTimestamp,
        ingestedAt: DateTime.utc(2026, 2, 24),
      );

      await db.into(db.driftDocuments).insert(doc.toCompanion());
      final row = await db.select(db.driftDocuments).getSingle();
      final result = row.toDomain();

      // updatedAt should pass through unchanged — it's a String, not DateTime
      expect(result.updatedAt, outlineTimestamp);
    });
  });

  group('Topic mapper', () {
    test('round-trips topic fields (documentIds via join table)', () async {
      final topic = Topic(
        id: 't1',
        name: 'Container Orchestration',
        description: 'Docker + K8s concepts',
        documentIds: const {'doc1', 'doc2', 'doc3'},
        createdAt: DateTime.utc(2026, 1, 15),
        lastIngestedAt: DateTime.utc(2026, 2, 20),
      );

      // Insert topic row
      await db.into(db.driftTopics).insert(topic.toCompanion());

      // Insert join rows (caller responsibility)
      for (final docId in topic.documentIds) {
        await db
            .into(db.driftTopicDocuments)
            .insert(
              DriftTopicDocumentsCompanion.insert(
                topicId: topic.id,
                documentId: docId,
              ),
            );
      }

      // Read back
      final topicRow = await db.select(db.driftTopics).getSingle();
      final joinRows = await db.select(db.driftTopicDocuments).get();
      final docIds = joinRows.map((r) => r.documentId).toSet();

      final result = topicRow.toDomain(documentIds: docIds);

      expect(result.id, topic.id);
      expect(result.name, topic.name);
      expect(result.description, topic.description);
      expect(result.documentIds, ISet(const {'doc1', 'doc2', 'doc3'}));
      expect(result.createdAt, topic.createdAt);
      expect(result.lastIngestedAt, topic.lastIngestedAt);
    });

    test('round-trips with null optional fields', () async {
      final topic = Topic(
        id: 't2',
        name: 'Minimal Topic',
        createdAt: DateTime.utc(2026, 2, 1),
      );

      await db.into(db.driftTopics).insert(topic.toCompanion());
      final topicRow = await db.select(db.driftTopics).getSingle();
      final result = topicRow.toDomain(documentIds: const {});

      expect(result.description, isNull);
      expect(result.documentIds, isEmpty);
      expect(result.lastIngestedAt, isNull);
    });
  });
}
