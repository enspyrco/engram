import 'dart:async';

import 'package:drift/native.dart';
import 'package:engram/src/crdt/hlc_manager.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/models/topic.dart';
import 'package:engram/src/storage/drift/drift_graph_repository.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:test/test.dart';

import '../../helpers/quiz_item_helpers.dart';

void main() {
  late EngramDatabase db;
  late DriftGraphRepository repo;

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGraphRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Test fixtures
  // ---------------------------------------------------------------------------

  /// Builds a realistic graph with all entity types populated.
  KnowledgeGraph fullGraph() {
    return KnowledgeGraph(
      concepts: [
        Concept(
          id: 'c1',
          name: 'Docker',
          description: 'Container runtime',
          sourceDocumentId: 'doc1',
          tags: const ['devops', 'containers'],
        ),
        Concept(
          id: 'c2',
          name: 'Kubernetes',
          description: 'Container orchestration',
          sourceDocumentId: 'doc1',
          parentConceptId: 'c1',
        ),
      ],
      relationships: const [
        Relationship(
          id: 'r1',
          fromConceptId: 'c2',
          toConceptId: 'c1',
          label: 'depends on',
          description: 'K8s requires Docker or similar runtime',
          type: RelationshipType.prerequisite,
        ),
      ],
      quizItems: [
        testQuizItem(
          id: 'q1',
          conceptId: 'c1',
          question: 'What is Docker?',
          answer: 'A container runtime',
          difficulty: 4.2,
          stability: 12.5,
          fsrsState: 2,
          lapses: 1,
          predictedDifficulty: 3.8,
          reviewCount: 7,
        ),
        testQuizItem(
          id: 'q2',
          conceptId: 'c2',
          question: 'What is a Pod?',
          answer: 'Smallest K8s unit',
        ),
      ],
      documentMetadata: [
        DocumentMetadata(
          documentId: 'doc1',
          title: 'Container Basics',
          updatedAt: '2026-02-20T10:00:00.000Z',
          ingestedAt: DateTime.utc(2026, 2, 24),
          collectionId: 'col1',
          collectionName: 'DevOps',
          ingestedText: 'Docker is a container runtime...',
        ),
      ],
      topics: [
        Topic(
          id: 't1',
          name: 'Containers',
          description: 'Docker and K8s',
          documentIds: const {'doc1'},
          createdAt: DateTime.utc(2026, 1, 15),
          lastIngestedAt: DateTime.utc(2026, 2, 20),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // load
  // ---------------------------------------------------------------------------

  group('load', () {
    test('returns empty graph when DB is empty', () async {
      final graph = await repo.load();

      expect(graph.concepts, isEmpty);
      expect(graph.relationships, isEmpty);
      expect(graph.quizItems, isEmpty);
      expect(graph.documentMetadata, isEmpty);
      expect(graph.topics, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // save + load round-trip
  // ---------------------------------------------------------------------------

  group('save + load', () {
    test('round-trips full KnowledgeGraph', () async {
      final original = fullGraph();

      await repo.save(original);
      final loaded = await repo.load();

      expect(loaded.concepts.length, original.concepts.length);
      expect(loaded.relationships.length, original.relationships.length);
      expect(loaded.quizItems.length, original.quizItems.length);
      expect(loaded.documentMetadata.length, original.documentMetadata.length);
      expect(loaded.topics.length, original.topics.length);

      // Verify content
      final c1 = loaded.concepts.firstWhere((c) => c.id == 'c1');
      expect(c1.name, 'Docker');
      expect(c1.tags.toList(), ['devops', 'containers']);
      expect(c1.parentConceptId, isNull);

      final c2 = loaded.concepts.firstWhere((c) => c.id == 'c2');
      expect(c2.parentConceptId, 'c1');

      final r1 = loaded.relationships.first;
      expect(r1.type, RelationshipType.prerequisite);
      expect(r1.description, 'K8s requires Docker or similar runtime');

      final q1 = loaded.quizItems.firstWhere((q) => q.id == 'q1');
      expect(q1.difficulty, 4.2);
      expect(q1.stability, 12.5);
      expect(q1.fsrsState, 2);
      expect(q1.lapses, 1);
      expect(q1.predictedDifficulty, 3.8);
      expect(q1.reviewCount, 7);

      final doc = loaded.documentMetadata.first;
      expect(doc.collectionId, 'col1');
      expect(doc.ingestedText, 'Docker is a container runtime...');

      final topic = loaded.topics.first;
      expect(topic.documentIds.length, 1);
      expect(topic.documentIds.contains('doc1'), isTrue);
      expect(topic.lastIngestedAt, DateTime.utc(2026, 2, 20));
    });

    test(
      'replaces all data atomically (save A, save B, only B exists)',
      () async {
        final graphA = fullGraph();
        await repo.save(graphA);

        // Save a completely different graph
        final graphB = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'cx',
              name: 'Rust',
              description: 'Systems language',
              sourceDocumentId: 'docX',
            ),
          ],
        );
        await repo.save(graphB);

        final loaded = await repo.load();

        // Only graph B data should exist
        expect(loaded.concepts.length, 1);
        expect(loaded.concepts.first.id, 'cx');
        expect(loaded.relationships, isEmpty);
        expect(loaded.quizItems, isEmpty);
        expect(loaded.documentMetadata, isEmpty);
        expect(loaded.topics, isEmpty);
      },
    );

    test('handles empty graph', () async {
      // Save non-empty first
      await repo.save(fullGraph());

      // Overwrite with empty
      await repo.save(KnowledgeGraph());

      final loaded = await repo.load();
      expect(loaded.concepts, isEmpty);
      expect(loaded.relationships, isEmpty);
      expect(loaded.quizItems, isEmpty);
      expect(loaded.documentMetadata, isEmpty);
      expect(loaded.topics, isEmpty);
    });

    test('normalizes topic documentIds into join table', () async {
      final graph = KnowledgeGraph(
        topics: [
          Topic(
            id: 't1',
            name: 'Multi-doc topic',
            documentIds: const {'doc1', 'doc2', 'doc3'},
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      await repo.save(graph);
      final loaded = await repo.load();

      final topic = loaded.topics.first;
      expect(topic.documentIds.length, 3);
      expect(topic.documentIds, containsAll(['doc1', 'doc2', 'doc3']));
    });
  });

  // ---------------------------------------------------------------------------
  // updateQuizItem
  // ---------------------------------------------------------------------------

  group('updateQuizItem', () {
    test('writes single row, others unchanged', () async {
      final graph = fullGraph();
      await repo.save(graph);

      // Update q1 with new FSRS state
      final updatedItem = testQuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is Docker?',
        answer: 'A container runtime',
        difficulty: 6.0,
        stability: 20.0,
        fsrsState: 2,
        lapses: 2,
        reviewCount: 8,
        nextReview: DateTime.utc(2026, 3, 15),
        lastReview: DateTime.utc(2026, 2, 24),
      );

      await repo.updateQuizItem(graph, updatedItem);
      final loaded = await repo.load();

      // Updated item should have new values
      final q1 = loaded.quizItems.firstWhere((q) => q.id == 'q1');
      expect(q1.difficulty, 6.0);
      expect(q1.stability, 20.0);
      expect(q1.lapses, 2);
      expect(q1.reviewCount, 8);

      // Other quiz item should be unchanged
      final q2 = loaded.quizItems.firstWhere((q) => q.id == 'q2');
      expect(q2.question, 'What is a Pod?');

      // Other entities should be unchanged
      expect(loaded.concepts.length, 2);
      expect(loaded.relationships.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // saveSplitData
  // ---------------------------------------------------------------------------

  group('saveSplitData', () {
    test('is additive — originals and new coexist', () async {
      final graph = fullGraph();
      await repo.save(graph);

      // Split c1 into sub-concepts
      final newConcepts = [
        Concept(
          id: 'c1-sub1',
          name: 'Docker Images',
          description: 'Immutable app snapshots',
          sourceDocumentId: 'doc1',
          parentConceptId: 'c1',
        ),
        Concept(
          id: 'c1-sub2',
          name: 'Docker Containers',
          description: 'Running image instances',
          sourceDocumentId: 'doc1',
          parentConceptId: 'c1',
        ),
      ];

      const newRelationships = [
        Relationship(
          id: 'r-split1',
          fromConceptId: 'c1-sub1',
          toConceptId: 'c1',
          label: 'is part of',
          type: RelationshipType.composition,
        ),
        Relationship(
          id: 'r-split2',
          fromConceptId: 'c1-sub2',
          toConceptId: 'c1',
          label: 'is part of',
          type: RelationshipType.composition,
        ),
      ];

      final newQuizItems = [
        testQuizItem(
          id: 'q-sub1',
          conceptId: 'c1-sub1',
          question: 'What is a Docker image?',
          answer: 'An immutable snapshot',
        ),
        testQuizItem(
          id: 'q-sub2',
          conceptId: 'c1-sub2',
          question: 'What is a Docker container?',
          answer: 'A running image instance',
        ),
      ];

      await repo.saveSplitData(
        graph: graph,
        concepts: newConcepts,
        relationships: newRelationships,
        quizItems: newQuizItems,
      );

      final loaded = await repo.load();

      // Original + new
      expect(loaded.concepts.length, 4); // c1, c2, c1-sub1, c1-sub2
      expect(loaded.relationships.length, 3); // r1, r-split1, r-split2
      expect(loaded.quizItems.length, 4); // q1, q2, q-sub1, q-sub2

      // Original concept still exists
      expect(loaded.concepts.any((c) => c.id == 'c1'), isTrue);

      // New sub-concepts have correct parentConceptId
      final sub1 = loaded.concepts.firstWhere((c) => c.id == 'c1-sub1');
      expect(sub1.parentConceptId, 'c1');
    });
  });

  // ---------------------------------------------------------------------------
  // watch
  // ---------------------------------------------------------------------------

  group('watch', () {
    test('emits initial state then reacts to changes', () async {
      await repo.save(fullGraph());

      final emissions = <KnowledgeGraph>[];
      final completer = Completer<void>();
      var count = 0;

      final subscription = repo.watch().listen((graph) {
        emissions.add(graph);
        count++;
        // Expect 2 emissions: initial + after save
        if (count >= 2) completer.complete();
      });

      // Wait for initial emission
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emissions.length, 1);
      expect(emissions.first.concepts.length, 2);

      // Trigger a change
      await repo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'cx',
              name: 'Rust',
              description: 'Systems language',
              sourceDocumentId: 'docX',
            ),
          ],
        ),
      );

      // Wait for the second emission
      await completer.future.timeout(const Duration(seconds: 5));

      expect(emissions.length, greaterThanOrEqualTo(2));
      final last = emissions.last;
      expect(last.concepts.length, 1);
      expect(last.concepts.first.id, 'cx');

      await subscription.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  // FSRS state
  // ---------------------------------------------------------------------------

  group('FSRS state', () {
    test('full FSRS state survives round-trip', () async {
      final mastered = masteredQuizItem(
        id: 'qm',
        conceptId: 'c1',
        predictedDifficulty: 6.5,
        reviewCount: 12,
      );

      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Test',
            description: 'Test',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [mastered],
      );

      await repo.save(graph);
      final loaded = await repo.load();

      final item = loaded.quizItems.first;
      expect(item.isFsrs, isTrue);
      expect(item.isMasteredForUnlock, isTrue);
      expect(item.difficulty, 5.0);
      expect(item.stability, 25.0);
      expect(item.fsrsState, 2);
      expect(item.lapses, 0);
      expect(item.predictedDifficulty, 6.5);
      expect(item.reviewCount, 12);
      expect(item.lastReview, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Topic document aggregation
  // ---------------------------------------------------------------------------

  group('topic document aggregation', () {
    test('multiple topics with shared documents aggregate correctly', () async {
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Doc 1',
            updatedAt: '2026-01-01',
            ingestedAt: DateTime.utc(2026, 1, 1),
          ),
          DocumentMetadata(
            documentId: 'doc2',
            title: 'Doc 2',
            updatedAt: '2026-01-02',
            ingestedAt: DateTime.utc(2026, 1, 2),
          ),
          DocumentMetadata(
            documentId: 'doc3',
            title: 'Doc 3',
            updatedAt: '2026-01-03',
            ingestedAt: DateTime.utc(2026, 1, 3),
          ),
        ],
        topics: [
          Topic(
            id: 't1',
            name: 'Topic A',
            documentIds: const {'doc1', 'doc2'},
            createdAt: DateTime.utc(2026, 1, 1),
          ),
          Topic(
            id: 't2',
            name: 'Topic B',
            documentIds: const {'doc2', 'doc3'},
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      await repo.save(graph);
      final loaded = await repo.load();

      final topicA = loaded.topics.firstWhere((t) => t.id == 't1');
      final topicB = loaded.topics.firstWhere((t) => t.id == 't2');

      // Each topic gets its own document set
      expect(topicA.documentIds, containsAll(['doc1', 'doc2']));
      expect(topicA.documentIds.length, 2);

      expect(topicB.documentIds, containsAll(['doc2', 'doc3']));
      expect(topicB.documentIds.length, 2);

      // doc2 is shared but each topic independently tracks it
      expect(topicA.documentIds.contains('doc2'), isTrue);
      expect(topicB.documentIds.contains('doc2'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Upsert + orphan tombstoning (#41)
  // ---------------------------------------------------------------------------

  group('upsert + orphan tombstoning', () {
    test('orphan concepts are tombstoned, not deleted', () async {
      await repo.save(fullGraph()); // c1, c2

      // Save a graph that keeps c1 but drops c2
      final graphB = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker Updated',
            description: 'Updated description',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await repo.save(graphB);

      // load() should return only c1
      final loaded = await repo.load();
      expect(loaded.concepts.length, 1);
      expect(loaded.concepts.first.id, 'c1');
      expect(loaded.concepts.first.name, 'Docker Updated');

      // Raw DB should have c2 as tombstoned
      final rawConcepts = await db.select(db.driftConcepts).get();
      expect(rawConcepts.length, 2);
      final tombstoned = rawConcepts.firstWhere((c) => c.id == 'c2');
      expect(tombstoned.isDeleted, isTrue);
      final alive = rawConcepts.firstWhere((c) => c.id == 'c1');
      expect(alive.isDeleted, isFalse);
    });

    test('all entity types are tombstoned when saving empty graph', () async {
      await repo.save(fullGraph());

      // Save empty graph
      await repo.save(KnowledgeGraph());

      // load() should return empty
      final loaded = await repo.load();
      expect(loaded.concepts, isEmpty);
      expect(loaded.relationships, isEmpty);
      expect(loaded.quizItems, isEmpty);
      expect(loaded.documentMetadata, isEmpty);
      expect(loaded.topics, isEmpty);

      // Raw DB should have tombstoned rows
      final rawConcepts = await db.select(db.driftConcepts).get();
      expect(rawConcepts.length, 2);
      expect(rawConcepts.every((c) => c.isDeleted), isTrue);

      final rawRels = await db.select(db.driftRelationships).get();
      expect(rawRels.length, 1);
      expect(rawRels.every((r) => r.isDeleted), isTrue);

      final rawQuiz = await db.select(db.driftQuizItems).get();
      expect(rawQuiz.length, 2);
      expect(rawQuiz.every((q) => q.isDeleted), isTrue);

      final rawDocs = await db.select(db.driftDocuments).get();
      expect(rawDocs.length, 1);
      expect(rawDocs.every((d) => d.isDeleted), isTrue);

      final rawTopics = await db.select(db.driftTopics).get();
      expect(rawTopics.length, 1);
      expect(rawTopics.every((t) => t.isDeleted), isTrue);

      final rawTopicDocs = await db.select(db.driftTopicDocuments).get();
      expect(rawTopicDocs.length, 1);
      expect(rawTopicDocs.every((td) => td.isDeleted), isTrue);
    });

    test('re-inserting a tombstoned entity resurrects it', () async {
      final graph = fullGraph();
      await repo.save(graph);

      // Tombstone c1 via raw SQL (simulating a prior save that removed it)
      await db.customStatement(
        "UPDATE drift_concepts SET is_deleted = 1 WHERE id = 'c1'",
      );

      // Verify c1 is hidden
      var loaded = await repo.load();
      expect(loaded.concepts.any((c) => c.id == 'c1'), isFalse);

      // Save a graph that includes c1 — should resurrect it
      await repo.save(graph);
      loaded = await repo.load();
      expect(loaded.concepts.any((c) => c.id == 'c1'), isTrue);

      // Raw DB should show isDeleted = false
      final rawRow = (await db.select(db.driftConcepts).get()).firstWhere(
        (c) => c.id == 'c1',
      );
      expect(rawRow.isDeleted, isFalse);
    });

    test('pre-existing tombstones are preserved across saves', () async {
      await repo.save(fullGraph());

      // Tombstone c2 via raw SQL (simulating a CRDT merge from another device)
      await db.customStatement(
        "UPDATE drift_concepts SET is_deleted = 1, "
        "hlc = 'old-tombstone-hlc' WHERE id = 'c2'",
      );

      // Save a graph with only c1 — c2 should remain tombstoned
      final graphB = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await repo.save(graphB);

      // c2 should still exist in raw DB as tombstoned
      final rawConcepts = await db.select(db.driftConcepts).get();
      final c2 = rawConcepts.firstWhere((c) => c.id == 'c2');
      expect(c2.isDeleted, isTrue);
    });

    test('orphan topic-document pairs are tombstoned', () async {
      final graph = KnowledgeGraph(
        topics: [
          Topic(
            id: 't1',
            name: 'Topic A',
            documentIds: const {'doc1', 'doc2', 'doc3'},
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      await repo.save(graph);

      // Save with fewer documents
      final graphB = KnowledgeGraph(
        topics: [
          Topic(
            id: 't1',
            name: 'Topic A',
            documentIds: const {'doc1'},
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      await repo.save(graphB);

      // load() should show only doc1
      final loaded = await repo.load();
      expect(loaded.topics.first.documentIds, {'doc1'});

      // Raw DB should have 3 rows: doc1 alive, doc2 + doc3 tombstoned
      final rawPairs = await db.select(db.driftTopicDocuments).get();
      expect(rawPairs.length, 3);

      final alive = rawPairs.where((r) => !r.isDeleted).toList();
      expect(alive.length, 1);
      expect(alive.first.documentId, 'doc1');

      final tombstoned = rawPairs.where((r) => r.isDeleted).toList();
      expect(tombstoned.length, 2);
      expect(tombstoned.map((r) => r.documentId).toSet(), {'doc2', 'doc3'});
    });

    test('HLC is stamped on tombstoned orphan rows', () async {
      final hlcManager = HlcManager(nodeId: 'test-device-001');
      final hlcRepo = DriftGraphRepository(db: db, hlcManager: hlcManager);

      await hlcRepo.save(fullGraph()); // c1, c2

      // Save with only c1 — c2 becomes an orphan
      final graphB = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await hlcRepo.save(graphB);

      // Tombstoned c2 should have an HLC from the second save
      final rawConcepts = await db.select(db.driftConcepts).get();
      final c2 = rawConcepts.firstWhere((c) => c.id == 'c2');
      expect(c2.isDeleted, isTrue);
      expect(c2.hlc, isNotEmpty);
      expect(c2.hlc, contains('test-device-001'));

      // c1 should also have an HLC (from the upsert)
      final c1 = rawConcepts.firstWhere((c) => c.id == 'c1');
      expect(c1.hlc, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // purgeTombstones (#41)
  // ---------------------------------------------------------------------------

  group('purgeTombstones', () {
    late HlcManager hlcManager;
    late DriftGraphRepository hlcRepo;

    setUp(() {
      hlcManager = HlcManager(nodeId: 'test-device-001');
      hlcRepo = DriftGraphRepository(db: db, hlcManager: hlcManager);
    });

    test('physically deletes tombstoned rows older than threshold', () async {
      // Save and tombstone: save full graph, then save without c2/r1/q2
      await hlcRepo.save(fullGraph());

      await hlcRepo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Container runtime',
              sourceDocumentId: 'doc1',
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'c1')],
        ),
      );

      // c2, r1, q2 are tombstoned. Purge tombstones older than "now".
      final purgeThreshold = hlcManager.now().toString();
      final purged = await hlcRepo.purgeTombstones(before: purgeThreshold);

      // Should have purged tombstoned rows
      expect(purged, greaterThan(0));

      // Raw DB should no longer contain c2
      final rawConcepts = await db.select(db.driftConcepts).get();
      expect(rawConcepts.length, 1);
      expect(rawConcepts.first.id, 'c1');
    });

    test('tombstones newer than threshold survive purge', () async {
      await hlcRepo.save(fullGraph());

      // Record threshold BEFORE tombstoning
      final purgeThreshold = hlcManager.now().toString();

      // Now tombstone c2 (its HLC will be after purgeThreshold)
      await hlcRepo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Container runtime',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      final purged = await hlcRepo.purgeTombstones(before: purgeThreshold);

      // Tombstoned c2 has HLC > threshold, so it should survive
      expect(purged, 0);
      final rawConcepts = await db.select(db.driftConcepts).get();
      final c2 = rawConcepts.where((c) => c.id == 'c2');
      expect(c2.length, 1);
      expect(c2.first.isDeleted, isTrue);
    });

    test('non-deleted rows are never purged', () async {
      await hlcRepo.save(fullGraph());

      // Purge with a threshold far in the future
      const farFuture = '9999-12-31T23:59:59.999Z-ffff-future';
      final purged = await hlcRepo.purgeTombstones(before: farFuture);

      // Nothing should be purged — all rows are active
      expect(purged, 0);
      final rawConcepts = await db.select(db.driftConcepts).get();
      expect(rawConcepts.length, 2);
    });

    test('purges tombstones across all entity types', () async {
      await hlcRepo.save(fullGraph());

      // Tombstone everything
      await hlcRepo.save(KnowledgeGraph());

      // Purge all
      const farFuture = '9999-12-31T23:59:59.999Z-ffff-future';
      final purged = await hlcRepo.purgeTombstones(before: farFuture);

      // 2 concepts + 1 relationship + 2 quiz items + 1 document + 1 topic
      // + 1 topic-document = 8
      expect(purged, 8);

      // Raw DB should be empty
      expect(await db.select(db.driftConcepts).get(), isEmpty);
      expect(await db.select(db.driftRelationships).get(), isEmpty);
      expect(await db.select(db.driftQuizItems).get(), isEmpty);
      expect(await db.select(db.driftDocuments).get(), isEmpty);
      expect(await db.select(db.driftTopics).get(), isEmpty);
      expect(await db.select(db.driftTopicDocuments).get(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // HLC stamping (#41)
  // ---------------------------------------------------------------------------

  group('HLC stamping', () {
    late HlcManager hlcManager;
    late DriftGraphRepository hlcRepo;

    setUp(() {
      hlcManager = HlcManager(nodeId: 'test-device-001');
      hlcRepo = DriftGraphRepository(db: db, hlcManager: hlcManager);
    });

    test('save stamps all rows with HLC timestamps', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Test',
            description: 'Test',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [testQuizItem(id: 'q1', conceptId: 'c1')],
      );

      await hlcRepo.save(graph);

      // Read raw rows to verify HLC was stamped
      final concepts = await db.select(db.driftConcepts).get();
      expect(concepts.first.hlc, isNotEmpty);
      expect(concepts.first.hlc, contains('test-device-001'));

      final quizItems = await db.select(db.driftQuizItems).get();
      expect(quizItems.first.hlc, isNotEmpty);
      expect(quizItems.first.hlc, contains('test-device-001'));
    });

    test('updateQuizItem stamps the updated row with HLC', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Test',
            description: 'Test',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [testQuizItem(id: 'q1', conceptId: 'c1')],
      );

      await hlcRepo.save(graph);
      final hlcAfterSave = (await db.select(db.driftQuizItems).get()).first.hlc;

      // Update the quiz item
      final updated = testQuizItem(id: 'q1', conceptId: 'c1', difficulty: 5.0);
      await hlcRepo.updateQuizItem(graph, updated);

      final hlcAfterUpdate =
          (await db.select(db.driftQuizItems).get()).first.hlc;

      // HLC should have advanced
      expect(hlcAfterUpdate, isNot(equals(hlcAfterSave)));
      expect(hlcAfterUpdate.compareTo(hlcAfterSave), greaterThan(0));
    });

    test('saveSplitData stamps new rows with HLC', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Parent',
            description: 'Parent concept',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await hlcRepo.save(graph);

      await hlcRepo.saveSplitData(
        graph: graph,
        concepts: [
          Concept(
            id: 'c1-sub',
            name: 'Child',
            description: 'Child concept',
            sourceDocumentId: 'doc1',
            parentConceptId: 'c1',
          ),
        ],
        relationships: [],
        quizItems: [],
      );

      final concepts = await db.select(db.driftConcepts).get();
      final child = concepts.firstWhere((c) => c.id == 'c1-sub');
      expect(child.hlc, isNotEmpty);
      expect(child.hlc, contains('test-device-001'));
    });

    test('without HlcManager, hlc defaults to empty string', () async {
      // repo (without HlcManager) is the default from outer setUp
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Test',
            description: 'Test',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await repo.save(graph);

      final concepts = await db.select(db.driftConcepts).get();
      expect(concepts.first.hlc, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // isDeleted tombstone filtering (#41)
  // ---------------------------------------------------------------------------

  group('isDeleted filtering', () {
    test('load excludes rows with isDeleted = true', () async {
      // Insert a concept normally
      await repo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Visible',
              description: 'Should appear',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      // Tombstone it via raw SQL (simulating a CRDT merge)
      await db.customStatement(
        "UPDATE drift_concepts SET is_deleted = 1 WHERE id = 'c1'",
      );

      final loaded = await repo.load();
      expect(
        loaded.concepts,
        isEmpty,
        reason: 'Tombstoned concept should not appear in load()',
      );
    });

    test('tombstoned rows still exist in raw DB', () async {
      await repo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Tombstoned',
              description: 'Hidden but present',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      await db.customStatement(
        "UPDATE drift_concepts SET is_deleted = 1 WHERE id = 'c1'",
      );

      // load() should exclude it
      final loaded = await repo.load();
      expect(loaded.concepts, isEmpty);

      // But raw query should find it
      final rawRows = await db.select(db.driftConcepts).get();
      expect(rawRows.length, 1);
      expect(rawRows.first.isDeleted, isTrue);
    });

    test('isDeleted filtering works across all entity types', () async {
      await repo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'C',
              description: 'C',
              sourceDocumentId: 'doc1',
            ),
          ],
          relationships: const [
            Relationship(
              id: 'r1',
              fromConceptId: 'c1',
              toConceptId: 'c1',
              label: 'self',
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'c1')],
          documentMetadata: [
            DocumentMetadata(
              documentId: 'doc1',
              title: 'Doc',
              updatedAt: '2026-01-01',
              ingestedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        ),
      );

      // Tombstone all rows
      for (final table in [
        'drift_concepts',
        'drift_relationships',
        'drift_quiz_items',
        'drift_documents',
      ]) {
        await db.customStatement('UPDATE $table SET is_deleted = 1');
      }

      final loaded = await repo.load();
      expect(loaded.concepts, isEmpty);
      expect(loaded.relationships, isEmpty);
      expect(loaded.quizItems, isEmpty);
      expect(loaded.documentMetadata, isEmpty);
    });
  });
}
