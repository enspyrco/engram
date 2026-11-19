import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  late EngramDatabase db;

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftConcepts', () {
    test('insert and select round-trips all fields', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Docker',
              description: 'Container runtime',
              sourceDocumentId: 'doc1',
              tags: IList(const ['devops', 'containers']),
              parentConceptId: const Value('parent1'),
              hlc: const Value('2026-01-01T00:00:00Z-0001-abc'),
            ),
          );

      final rows = await db.select(db.driftConcepts).get();
      expect(rows, hasLength(1));

      final row = rows.first;
      expect(row.id, 'c1');
      expect(row.name, 'Docker');
      expect(row.description, 'Container runtime');
      expect(row.sourceDocumentId, 'doc1');
      expect(row.tags, IList(const ['devops', 'containers']));
      expect(row.parentConceptId, 'parent1');
      expect(row.embedding, isNull);
      expect(row.hlc, '2026-01-01T00:00:00Z-0001-abc');
    });

    test('tags survive JSON round-trip through IListStringConverter', () async {
      final tags = IList(const ['has "quotes"', 'special\tchars', '']);
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Test',
              description: 'Test concept',
              sourceDocumentId: 'doc1',
              tags: tags,
            ),
          );

      final row =
          await (db.select(db.driftConcepts)
            ..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.tags, tags);
    });

    test('empty tags list round-trips', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Test',
              description: 'Test concept',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      final row =
          await (db.select(db.driftConcepts)
            ..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.tags, isEmpty);
    });

    test('parentConceptId defaults to null', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Root',
              description: 'Root concept',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      final row =
          await (db.select(db.driftConcepts)
            ..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.parentConceptId, isNull);
    });

    test('hlc defaults to empty string', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Test',
              description: 'Test',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      final row =
          await (db.select(db.driftConcepts)
            ..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.hlc, '');
    });

    test('upsert replaces existing row', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Docker',
              description: 'v1',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      await db
          .into(db.driftConcepts)
          .insertOnConflictUpdate(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Docker Updated',
              description: 'v2',
              sourceDocumentId: 'doc1',
              tags: IList(const ['updated']),
            ),
          );

      final rows = await db.select(db.driftConcepts).get();
      expect(rows, hasLength(1));
      expect(rows.first.name, 'Docker Updated');
      expect(rows.first.tags, IList(const ['updated']));
    });
  });

  group('DriftRelationships', () {
    test('insert and select round-trips all fields', () async {
      await db
          .into(db.driftRelationships)
          .insert(
            DriftRelationshipsCompanion.insert(
              id: 'r1',
              fromConceptId: 'c1',
              toConceptId: 'c2',
              label: 'depends on',
              description: const Value('Docker depends on Linux'),
              type: RelationshipType.prerequisite,
            ),
          );

      final rows = await db.select(db.driftRelationships).get();
      expect(rows, hasLength(1));

      final row = rows.first;
      expect(row.id, 'r1');
      expect(row.fromConceptId, 'c1');
      expect(row.toConceptId, 'c2');
      expect(row.label, 'depends on');
      expect(row.description, 'Docker depends on Linux');
      expect(row.type, RelationshipType.prerequisite);
    });

    test('RelationshipType round-trips all values through the DB', () async {
      for (final type in RelationshipType.values) {
        await db
            .into(db.driftRelationships)
            .insert(
              DriftRelationshipsCompanion.insert(
                id: 'r_${type.name}',
                fromConceptId: 'c1',
                toConceptId: 'c2',
                label: type.name,
                type: type,
              ),
            );
      }

      final rows = await db.select(db.driftRelationships).get();
      expect(rows, hasLength(RelationshipType.values.length));

      for (final type in RelationshipType.values) {
        final row = rows.firstWhere((r) => r.id == 'r_${type.name}');
        expect(row.type, type, reason: '${type.name} should round-trip');
      }
    });
  });

  group('DriftQuizItems', () {
    test('insert and select round-trips all fields', () async {
      await db
          .into(db.driftQuizItems)
          .insert(
            DriftQuizItemsCompanion.insert(
              id: 'q1',
              conceptId: 'c1',
              question: 'What is Docker?',
              answer: 'A container runtime',
              interval: 10,
              nextReview: '2026-03-01T00:00:00.000Z',
              lastReview: const Value('2026-02-20T00:00:00.000Z'),
              difficulty: const Value(5.0),
              stability: const Value(10.0),
              fsrsState: const Value(2),
              lapses: const Value(1),
              predictedDifficulty: const Value(6.5),
              reviewCount: const Value(3),
            ),
          );

      final rows = await db.select(db.driftQuizItems).get();
      expect(rows, hasLength(1));

      final row = rows.first;
      expect(row.id, 'q1');
      expect(row.conceptId, 'c1');
      expect(row.question, 'What is Docker?');
      expect(row.answer, 'A container runtime');
      expect(row.interval, 10);
      expect(row.nextReview, '2026-03-01T00:00:00.000Z');
      expect(row.lastReview, '2026-02-20T00:00:00.000Z');
      expect(row.difficulty, 5.0);
      expect(row.stability, 10.0);
      expect(row.fsrsState, 2);
      expect(row.lapses, 1);
      expect(row.predictedDifficulty, 6.5);
      expect(row.reviewCount, 3);
    });

    test('nullable FSRS fields default to null', () async {
      await db
          .into(db.driftQuizItems)
          .insert(
            DriftQuizItemsCompanion.insert(
              id: 'q1',
              conceptId: 'c1',
              question: 'Q?',
              answer: 'A',
              interval: 0,
              nextReview: '2026-03-01T00:00:00.000Z',
            ),
          );

      final row =
          await (db.select(db.driftQuizItems)
            ..where((t) => t.id.equals('q1'))).getSingle();
      expect(row.lastReview, isNull);
      expect(row.difficulty, isNull);
      expect(row.stability, isNull);
      expect(row.fsrsState, isNull);
      expect(row.lapses, isNull);
      expect(row.predictedDifficulty, isNull);
      expect(row.reviewCount, 0);
    });
  });

  group('DriftDocuments', () {
    test('insert and select round-trips all fields', () async {
      await db
          .into(db.driftDocuments)
          .insert(
            DriftDocumentsCompanion.insert(
              documentId: 'doc1',
              title: 'Container Guide',
              updatedAt: '2026-01-01T00:00:00.000Z',
              ingestedAt: '2026-01-01T12:00:00.000Z',
              collectionId: const Value('col1'),
              collectionName: const Value('DevOps'),
              ingestedText: const Value('# Container Guide\nDocker is...'),
            ),
          );

      final rows = await db.select(db.driftDocuments).get();
      expect(rows, hasLength(1));

      final row = rows.first;
      expect(row.documentId, 'doc1');
      expect(row.title, 'Container Guide');
      expect(row.updatedAt, '2026-01-01T00:00:00.000Z');
      expect(row.ingestedAt, '2026-01-01T12:00:00.000Z');
      expect(row.collectionId, 'col1');
      expect(row.collectionName, 'DevOps');
      expect(row.ingestedText, '# Container Guide\nDocker is...');
    });

    test('nullable fields default to null', () async {
      await db
          .into(db.driftDocuments)
          .insert(
            DriftDocumentsCompanion.insert(
              documentId: 'doc1',
              title: 'Minimal',
              updatedAt: '2026-01-01T00:00:00.000Z',
              ingestedAt: '2026-01-01T12:00:00.000Z',
            ),
          );

      final row =
          await (db.select(db.driftDocuments)
            ..where((t) => t.documentId.equals('doc1'))).getSingle();
      expect(row.collectionId, isNull);
      expect(row.collectionName, isNull);
      expect(row.ingestedText, isNull);
    });
  });

  group('DriftTopics', () {
    test('insert and select round-trips all fields', () async {
      await db
          .into(db.driftTopics)
          .insert(
            DriftTopicsCompanion.insert(
              id: 't1',
              name: 'Containers',
              description: const Value('Everything about containers'),
              createdAt: '2026-01-01T00:00:00.000Z',
              lastIngestedAt: const Value('2026-02-01T00:00:00.000Z'),
            ),
          );

      final rows = await db.select(db.driftTopics).get();
      expect(rows, hasLength(1));

      final row = rows.first;
      expect(row.id, 't1');
      expect(row.name, 'Containers');
      expect(row.description, 'Everything about containers');
      expect(row.createdAt, '2026-01-01T00:00:00.000Z');
      expect(row.lastIngestedAt, '2026-02-01T00:00:00.000Z');
    });
  });

  group('DriftTopicDocuments', () {
    test('insert and select join table rows', () async {
      await db
          .into(db.driftTopicDocuments)
          .insert(
            DriftTopicDocumentsCompanion.insert(
              topicId: 't1',
              documentId: 'doc1',
            ),
          );
      await db
          .into(db.driftTopicDocuments)
          .insert(
            DriftTopicDocumentsCompanion.insert(
              topicId: 't1',
              documentId: 'doc2',
            ),
          );

      final rows =
          await (db.select(db.driftTopicDocuments)
            ..where((t) => t.topicId.equals('t1'))).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.documentId).toSet(), {'doc1', 'doc2'});
    });

    test('composite primary key prevents duplicates', () async {
      await db
          .into(db.driftTopicDocuments)
          .insert(
            DriftTopicDocumentsCompanion.insert(
              topicId: 't1',
              documentId: 'doc1',
            ),
          );

      // Inserting the same (topicId, documentId) pair should fail.
      expect(
        () => db
            .into(db.driftTopicDocuments)
            .insert(
              DriftTopicDocumentsCompanion.insert(
                topicId: 't1',
                documentId: 'doc1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('same document can belong to multiple topics', () async {
      await db
          .into(db.driftTopicDocuments)
          .insert(
            DriftTopicDocumentsCompanion.insert(
              topicId: 't1',
              documentId: 'doc1',
            ),
          );
      await db
          .into(db.driftTopicDocuments)
          .insert(
            DriftTopicDocumentsCompanion.insert(
              topicId: 't2',
              documentId: 'doc1',
            ),
          );

      final rows =
          await (db.select(db.driftTopicDocuments)
            ..where((t) => t.documentId.equals('doc1'))).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.topicId).toSet(), {'t1', 't2'});
    });
  });

  group('Schema migration v1→v2', () {
    test('adds is_deleted column with default false to all tables', () async {
      // Create a v1-style database by inserting data, then verify
      // that the is_deleted column exists and defaults to false.
      // (In-memory databases always get the latest schema via createAll(),
      // so the is_deleted column is created fresh. This test verifies the
      // column's default behavior which matches the migration's DEFAULT 0.)
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Test',
              description: 'Test',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      final row = (await db.select(db.driftConcepts).get()).first;
      expect(
        row.isDeleted,
        isFalse,
        reason: 'is_deleted should default to false',
      );
    });

    test('is_deleted column exists on all tables', () async {
      // Verify we can query with isDeleted filter on every table.
      // If the column didn't exist, these would throw.
      await (db.select(db.driftConcepts)
        ..where((t) => t.isDeleted.equals(false))).get();
      await (db.select(db.driftRelationships)
        ..where((t) => t.isDeleted.equals(false))).get();
      await (db.select(db.driftQuizItems)
        ..where((t) => t.isDeleted.equals(false))).get();
      await (db.select(db.driftDocuments)
        ..where((t) => t.isDeleted.equals(false))).get();
      await (db.select(db.driftTopics)
        ..where((t) => t.isDeleted.equals(false))).get();
      await (db.select(db.driftTopicDocuments)
        ..where((t) => t.isDeleted.equals(false))).get();
    });

    test('is_deleted can be set to true (tombstone)', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Test',
              description: 'Test',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      // Tombstone via update
      await (db.update(db.driftConcepts)..where(
        (t) => t.id.equals('c1'),
      )).write(const DriftConceptsCompanion(isDeleted: Value(true)));

      final row = (await db.select(db.driftConcepts).get()).first;
      expect(row.isDeleted, isTrue);
    });
  });

  group('Schema migration v3→v4', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('engram_migration_');
      file = File('${dir.path}/engram.sqlite');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    /// Writes a database file in the v3 shape: the current schema without
    /// the `rubric` column, holding one quiz item, at `user_version = 3`.
    Future<void> writeV3Database() async {
      final v4 = EngramDatabase.forTesting(NativeDatabase(file));
      await v4
          .into(v4.driftQuizItems)
          .insert(
            DriftQuizItemsCompanion.insert(
              id: 'q1',
              conceptId: 'c1',
              question: 'Q?',
              answer: 'A.',
              interval: 0,
              nextReview: '2026-01-01T00:00:00.000Z',
            ),
          );
      await v4.customStatement(
        'ALTER TABLE drift_quiz_items DROP COLUMN rubric',
      );
      await v4.customStatement('PRAGMA user_version = 3');
      await v4.close();
    }

    test('upgrading adds the rubric column and keeps existing rows', () async {
      await writeV3Database();

      final upgraded = EngramDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      final rows = await upgraded.select(upgraded.driftQuizItems).get();
      expect(rows.single.id, 'q1');
      expect(rows.single.rubric, isNull);

      await (upgraded.update(upgraded.driftQuizItems)..where(
        (t) => t.id.equals('q1'),
      )).write(DriftQuizItemsCompanion(rubric: Value(IList(const ['a', 'b']))));
      final updated =
          await upgraded.select(upgraded.driftQuizItems).getSingle();
      expect(updated.rubric?.toList(), ['a', 'b']);
    });
  });

  group('Cross-table operations', () {
    test('delete cascade scenario — orphan cleanup pattern', () async {
      // Insert a concept and its quiz item
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Docker',
              description: 'Container runtime',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );
      await db
          .into(db.driftQuizItems)
          .insert(
            DriftQuizItemsCompanion.insert(
              id: 'q1',
              conceptId: 'c1',
              question: 'What is Docker?',
              answer: 'A container runtime',
              interval: 0,
              nextReview: '2026-03-01T00:00:00.000Z',
            ),
          );

      // Simulate orphan cleanup: delete concept, then quiz items
      // referencing it (manual — no FK cascade, matching Firestore semantics).
      await (db.delete(db.driftConcepts)..where((t) => t.id.equals('c1'))).go();
      await (db.delete(db.driftQuizItems)
        ..where((t) => t.conceptId.equals('c1'))).go();

      expect(await db.select(db.driftConcepts).get(), isEmpty);
      expect(await db.select(db.driftQuizItems).get(), isEmpty);
    });

    test('transaction rolls back on failure', () async {
      await db
          .into(db.driftConcepts)
          .insert(
            DriftConceptsCompanion.insert(
              id: 'c1',
              name: 'Existing',
              description: 'Already here',
              sourceDocumentId: 'doc1',
              tags: IList(const []),
            ),
          );

      try {
        await db.transaction(() async {
          // This succeeds
          await db
              .into(db.driftConcepts)
              .insertOnConflictUpdate(
                DriftConceptsCompanion.insert(
                  id: 'c1',
                  name: 'Modified',
                  description: 'Changed in transaction',
                  sourceDocumentId: 'doc1',
                  tags: IList(const []),
                ),
              );

          // Force a rollback
          throw Exception('Simulated failure');
        });
      } catch (_) {
        // Expected
      }

      // Original row should be unchanged after rollback
      final row =
          await (db.select(db.driftConcepts)
            ..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.name, 'Existing');
    });
  });
}
