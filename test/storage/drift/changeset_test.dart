import 'dart:async';

import 'package:drift/native.dart';
import 'package:engram/src/crdt/graph_changeset.dart';
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
  // -------------------------------------------------------------------------
  // Two-device simulation setup
  // -------------------------------------------------------------------------

  late EngramDatabase dbA;
  late EngramDatabase dbB;
  late HlcManager hlcA;
  late HlcManager hlcB;
  late DriftGraphRepository repoA;
  late DriftGraphRepository repoB;

  setUp(() {
    dbA = EngramDatabase.forTesting(NativeDatabase.memory());
    dbB = EngramDatabase.forTesting(NativeDatabase.memory());
    hlcA = HlcManager(nodeId: 'device-A');
    hlcB = HlcManager(nodeId: 'device-B');
    repoA = DriftGraphRepository(db: dbA, hlcManager: hlcA);
    repoB = DriftGraphRepository(db: dbB, hlcManager: hlcB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  // -------------------------------------------------------------------------
  // Test fixtures
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // getChangeset
  // -------------------------------------------------------------------------

  group('getChangeset', () {
    test('returns empty changeset on empty DB', () async {
      final changeset = await repoA.getChangeset(modifiedAfter: '');
      expect(changeset.isEmpty, isTrue);
      expect(changeset.recordCount, 0);
    });

    test('returns full state when modifiedAfter is empty string', () async {
      await repoA.save(fullGraph());

      final changeset = await repoA.getChangeset(modifiedAfter: '');

      expect(changeset.concepts.length, 2);
      expect(changeset.relationships.length, 1);
      expect(changeset.quizItems.length, 2);
      expect(changeset.documents.length, 1);
      expect(changeset.topics.length, 1);
      expect(changeset.topicDocuments.length, 1);
      expect(changeset.recordCount, 8);
    });

    test('returns incremental changes after a given HLC', () async {
      await repoA.save(fullGraph());

      // Record the HLC after the first save
      final afterFirstSave = await repoA.getLastModified();

      // Make a second change — update a quiz item
      final updated = testQuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is Docker?',
        answer: 'A container runtime (updated)',
        difficulty: 6.0,
        reviewCount: 8,
      );
      await repoA.updateQuizItem(await repoA.load(), updated);

      // Changeset since first save should only contain q1
      final changeset = await repoA.getChangeset(modifiedAfter: afterFirstSave);

      expect(changeset.quizItems.length, 1);
      expect(changeset.quizItems.first.id, 'q1');
      expect(changeset.concepts, isEmpty);
      expect(changeset.relationships, isEmpty);
    });

    test('includes tombstoned rows in changeset', () async {
      await repoA.save(fullGraph());
      final afterFirstSave = await repoA.getLastModified();

      // Tombstone c2 by saving without it
      await repoA.save(
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

      final changeset = await repoA.getChangeset(modifiedAfter: afterFirstSave);

      // Should include tombstoned c2
      final tombstoned = changeset.concepts.where((c) => c.id == 'c2').toList();
      expect(tombstoned.length, 1);
      expect(tombstoned.first.isDeleted, isTrue);
    });

    test('returns empty changeset for future HLC', () async {
      await repoA.save(fullGraph());

      const futureHlc = '9999-12-31T23:59:59.999Z-ffff-future';
      final changeset = await repoA.getChangeset(modifiedAfter: futureHlc);

      expect(changeset.isEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // mergeChangeset
  // -------------------------------------------------------------------------

  group('mergeChangeset', () {
    test('newer incoming row wins over existing (LWW)', () async {
      // Device A saves the full graph
      await repoA.save(fullGraph());

      // Device B saves the same concept with a different description
      await repoB.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Updated by device B',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      // Device B's HLC is newer because it wrote after A
      final changesetFromB = await repoB.getChangeset(modifiedAfter: '');

      final written = await repoA.mergeChangeset(changesetFromB);
      expect(written, greaterThan(0));

      // Verify B's version won on device A
      final loaded = await repoA.load();
      final c1 = loaded.concepts.firstWhere((c) => c.id == 'c1');
      expect(c1.description, 'Updated by device B');
    });

    test('older incoming row is skipped', () async {
      // Device A saves first
      await repoA.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Original by A',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      // Get changeset from A (older)
      final changesetFromA = await repoA.getChangeset(modifiedAfter: '');

      // Device B saves a newer version
      await repoB.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Updated by B (newer)',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      // Merge A's older changeset into B — should be skipped
      final written = await repoB.mergeChangeset(changesetFromA);
      expect(written, 0);

      // B's version should survive
      final loaded = await repoB.load();
      final c1 = loaded.concepts.firstWhere((c) => c.id == 'c1');
      expect(c1.description, 'Updated by B (newer)');
    });

    test('idempotent — re-merging same changeset has no effect', () async {
      await repoA.save(fullGraph());
      final changeset = await repoA.getChangeset(modifiedAfter: '');

      // First merge into B
      final written1 = await repoB.mergeChangeset(changeset);
      expect(written1, 8); // all rows new

      // Second merge — same data, should be skipped
      final written2 = await repoB.mergeChangeset(changeset);
      expect(written2, 0);

      // Data should be identical
      final loadedB = await repoB.load();
      expect(loadedB.concepts.length, 2);
      expect(loadedB.relationships.length, 1);
    });

    test('tombstone propagates via merge', () async {
      // Both devices start with the same graph
      await repoA.save(fullGraph());
      final initialChangeset = await repoA.getChangeset(modifiedAfter: '');
      await repoB.mergeChangeset(initialChangeset);

      // Device A tombstones c2
      await repoA.save(
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

      // Get delta from A (includes the tombstone)
      final afterInitial = initialChangeset.concepts.first.hlc;
      final delta = await repoA.getChangeset(modifiedAfter: afterInitial);

      // Merge into B
      await repoB.mergeChangeset(delta);

      // B should no longer see c2
      final loaded = await repoB.load();
      expect(loaded.concepts.any((c) => c.id == 'c2'), isFalse);
      expect(loaded.concepts.length, 1);
      expect(loaded.concepts.first.id, 'c1');

      // But c2 should exist as tombstone in raw DB
      final rawConcepts = await dbB.select(dbB.driftConcepts).get();
      final c2 = rawConcepts.where((c) => c.id == 'c2');
      expect(c2.length, 1);
      expect(c2.first.isDeleted, isTrue);
    });

    test('resurrection — newer alive row overwrites tombstone', () async {
      // Device A has c1 tombstoned
      await repoA.save(fullGraph());
      await repoA.save(KnowledgeGraph()); // tombstone everything

      // Device B resurrects c1 with a newer HLC
      await repoB.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker Resurrected',
              description: 'Back from the dead',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      final changesetFromB = await repoB.getChangeset(modifiedAfter: '');
      await repoA.mergeChangeset(changesetFromB);

      // c1 should be alive on device A
      final loaded = await repoA.load();
      final c1 = loaded.concepts.where((c) => c.id == 'c1');
      expect(c1.length, 1);
      expect(c1.first.name, 'Docker Resurrected');
    });

    test('HLC advances on merge (causal ordering)', () async {
      await repoA.save(fullGraph());
      final hlcBeforeMerge = hlcB.canonicalTime.toString();

      final changeset = await repoA.getChangeset(modifiedAfter: '');
      await repoB.mergeChangeset(changeset);

      final hlcAfterMerge = hlcB.canonicalTime.toString();

      // B's clock should have advanced
      expect(hlcAfterMerge.compareTo(hlcBeforeMerge), greaterThan(0));
    });

    test('merges all table types correctly', () async {
      await repoA.save(fullGraph());
      final changeset = await repoA.getChangeset(modifiedAfter: '');

      final written = await repoB.mergeChangeset(changeset);
      expect(written, 8); // 2c + 1r + 2q + 1d + 1t + 1td

      final loaded = await repoB.load();
      expect(loaded.concepts.length, 2);
      expect(loaded.relationships.length, 1);
      expect(loaded.quizItems.length, 2);
      expect(loaded.documentMetadata.length, 1);
      expect(loaded.topics.length, 1);
      expect(loaded.topics.first.documentIds.length, 1);

      // Verify content fidelity
      final q1 = loaded.quizItems.firstWhere((q) => q.id == 'q1');
      expect(q1.difficulty, 4.2);
      expect(q1.stability, 12.5);
      expect(q1.predictedDifficulty, 3.8);
      expect(q1.reviewCount, 7);

      final doc = loaded.documentMetadata.first;
      expect(doc.collectionId, 'col1');
      expect(doc.ingestedText, 'Docker is a container runtime...');

      final r1 = loaded.relationships.first;
      expect(r1.type, RelationshipType.prerequisite);
      expect(r1.description, 'K8s requires Docker or similar runtime');
    });

    test('watch() fires after merge', () async {
      // Set up a watch on device B
      final emissions = <KnowledgeGraph>[];
      final completer = Completer<void>();
      var count = 0;

      final subscription = repoB.watch().listen((graph) {
        emissions.add(graph);
        count++;
        if (count >= 2) completer.complete();
      });

      // Wait for initial empty emission
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emissions.length, 1);
      expect(emissions.first.concepts, isEmpty);

      // Merge a changeset from A
      await repoA.save(fullGraph());
      final changeset = await repoA.getChangeset(modifiedAfter: '');
      await repoB.mergeChangeset(changeset);

      await completer.future.timeout(const Duration(seconds: 5));
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.concepts.length, 2);

      await subscription.cancel();
    });

    test('empty changeset returns 0 without error', () async {
      final written = await repoA.mergeChangeset(const GraphChangeset());
      expect(written, 0);
    });
  });

  // -------------------------------------------------------------------------
  // Serialization round-trip
  // -------------------------------------------------------------------------

  group('serialization', () {
    test('toJson/fromJson round-trips all column types', () async {
      await repoA.save(fullGraph());
      final original = await repoA.getChangeset(modifiedAfter: '');

      final json = original.toJson();
      final restored = GraphChangeset.fromJson(json);

      expect(restored.recordCount, original.recordCount);

      // Concepts
      expect(restored.concepts.length, original.concepts.length);
      final c1 = restored.concepts.firstWhere((c) => c.id == 'c1');
      expect(c1.name, 'Docker');
      expect(c1.tags.toList(), ['devops', 'containers']);
      expect(c1.parentConceptId, isNull);
      expect(c1.hlc, isNotEmpty);
      expect(c1.isDeleted, isFalse);

      final c2 = restored.concepts.firstWhere((c) => c.id == 'c2');
      expect(c2.parentConceptId, 'c1');

      // Relationships
      final r1 = restored.relationships.first;
      expect(r1.type, RelationshipType.prerequisite);
      expect(r1.description, 'K8s requires Docker or similar runtime');

      // Quiz items — FSRS state
      final q1 = restored.quizItems.firstWhere((q) => q.id == 'q1');
      expect(q1.difficulty, 4.2);
      expect(q1.stability, 12.5);
      expect(q1.fsrsState, 2);
      expect(q1.lapses, 1);
      expect(q1.predictedDifficulty, 3.8);
      expect(q1.reviewCount, 7);

      // Documents
      final doc = restored.documents.first;
      expect(doc.documentId, 'doc1');
      expect(doc.collectionId, 'col1');
      expect(doc.ingestedText, 'Docker is a container runtime...');

      // Topics
      final t1 = restored.topics.first;
      expect(t1.name, 'Containers');
      expect(t1.description, 'Docker and K8s');

      // Topic documents
      final td = restored.topicDocuments.first;
      expect(td.topicId, 't1');
      expect(td.documentId, 'doc1');
    });

    test('fromJson handles missing table keys gracefully', () {
      final partial = GraphChangeset.fromJson({
        'drift_concepts': [
          {
            'id': 'c1',
            'name': 'Test',
            'description': 'Test',
            'source_document_id': 'doc1',
            'tags': '[]',
            'parent_concept_id': null,
            'embedding': null,
            'hlc': 'some-hlc',
            'is_deleted': 0,
          },
        ],
        // Other tables missing — should default to empty
      });

      expect(partial.concepts.length, 1);
      expect(partial.relationships, isEmpty);
      expect(partial.quizItems, isEmpty);
      expect(partial.documents, isEmpty);
      expect(partial.topics, isEmpty);
      expect(partial.topicDocuments, isEmpty);
    });

    test('is_deleted handles both bool and int encoding', () {
      final withInt = GraphChangeset.fromJson({
        'drift_concepts': [
          {
            'id': 'c1',
            'name': 'Test',
            'description': 'Test',
            'source_document_id': 'doc1',
            'tags': '[]',
            'parent_concept_id': null,
            'embedding': null,
            'hlc': 'hlc1',
            'is_deleted': 1,
          },
        ],
      });
      expect(withInt.concepts.first.isDeleted, isTrue);

      final withBool = GraphChangeset.fromJson({
        'drift_concepts': [
          {
            'id': 'c2',
            'name': 'Test',
            'description': 'Test',
            'source_document_id': 'doc1',
            'tags': '[]',
            'parent_concept_id': null,
            'embedding': null,
            'hlc': 'hlc2',
            'is_deleted': true,
          },
        ],
      });
      expect(withBool.concepts.first.isDeleted, isTrue);
    });

    test('composite key handling for topic-documents', () async {
      // Save a topic with multiple documents
      await repoA.save(
        KnowledgeGraph(
          topics: [
            Topic(
              id: 't1',
              name: 'Multi-doc',
              documentIds: const {'doc1', 'doc2', 'doc3'},
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        ),
      );

      final changeset = await repoA.getChangeset(modifiedAfter: '');
      final json = changeset.toJson();
      final restored = GraphChangeset.fromJson(json);

      expect(restored.topicDocuments.length, 3);
      final topicIds = restored.topicDocuments.map((td) => td.topicId).toSet();
      expect(topicIds, {'t1'});
      final docIds = restored.topicDocuments.map((td) => td.documentId).toSet();
      expect(docIds, {'doc1', 'doc2', 'doc3'});
    });
  });

  // -------------------------------------------------------------------------
  // getLastModified
  // -------------------------------------------------------------------------

  group('getLastModified', () {
    test('returns empty string on empty DB', () async {
      final hlc = await repoA.getLastModified();
      expect(hlc, isEmpty);
    });

    test('returns the highest HLC across all tables', () async {
      await repoA.save(fullGraph());
      final afterSave = await repoA.getLastModified();
      expect(afterSave, isNotEmpty);
      expect(afterSave, contains('device-A'));

      // Update a quiz item — should produce a newer HLC
      final updated = testQuizItem(id: 'q1', conceptId: 'c1', difficulty: 6.0);
      await repoA.updateQuizItem(await repoA.load(), updated);

      final afterUpdate = await repoA.getLastModified();
      expect(afterUpdate.compareTo(afterSave), greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // Two-way sync scenario (integration)
  // -------------------------------------------------------------------------

  group('two-way sync', () {
    test(
      'both devices converge after bidirectional changeset exchange',
      () async {
        // Device A adds concepts c1, c2
        await repoA.save(
          KnowledgeGraph(
            concepts: [
              Concept(
                id: 'c1',
                name: 'Docker',
                description: 'Container runtime',
                sourceDocumentId: 'doc1',
              ),
              Concept(
                id: 'c2',
                name: 'Kubernetes',
                description: 'Orchestration',
                sourceDocumentId: 'doc1',
              ),
            ],
          ),
        );

        // Device B adds concepts c3, c4 (independently)
        await repoB.save(
          KnowledgeGraph(
            concepts: [
              Concept(
                id: 'c3',
                name: 'Terraform',
                description: 'IaC tool',
                sourceDocumentId: 'doc2',
              ),
              Concept(
                id: 'c4',
                name: 'Ansible',
                description: 'Configuration mgmt',
                sourceDocumentId: 'doc2',
              ),
            ],
          ),
        );

        // Exchange changesets
        final fromA = await repoA.getChangeset(modifiedAfter: '');
        final fromB = await repoB.getChangeset(modifiedAfter: '');

        await repoA.mergeChangeset(fromB);
        await repoB.mergeChangeset(fromA);

        // Both should have all 4 concepts
        final loadedA = await repoA.load();
        final loadedB = await repoB.load();

        expect(loadedA.concepts.length, 4);
        expect(loadedB.concepts.length, 4);

        final idsA = loadedA.concepts.map((c) => c.id).toSet();
        final idsB = loadedB.concepts.map((c) => c.id).toSet();
        expect(idsA, idsB);
        expect(idsA, {'c1', 'c2', 'c3', 'c4'});
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3-device convergence
  // -------------------------------------------------------------------------

  group('3-device convergence', () {
    late EngramDatabase dbC;
    late HlcManager hlcC;
    late DriftGraphRepository repoC;

    setUp(() {
      dbC = EngramDatabase.forTesting(NativeDatabase.memory());
      hlcC = HlcManager(nodeId: 'device-C');
      repoC = DriftGraphRepository(db: dbC, hlcManager: hlcC);
    });

    tearDown(() async {
      await dbC.close();
    });

    test(
      'A, B, C edit same concept — different merge orders — all converge',
      () async {
        // All three start with the same concept
        final base = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Base',
              sourceDocumentId: 'doc1',
            ),
          ],
        );
        await repoA.save(base);
        final seed = await repoA.getChangeset(modifiedAfter: '');
        await repoB.mergeChangeset(seed);
        await repoC.mergeChangeset(seed);

        // Each device edits c1 at staggered times (A first, C last = newest)
        await repoA.save(
          KnowledgeGraph(
            concepts: [
              Concept(
                id: 'c1',
                name: 'Docker',
                description: 'Edit by A',
                sourceDocumentId: 'doc1',
              ),
            ],
          ),
        );
        await repoB.save(
          KnowledgeGraph(
            concepts: [
              Concept(
                id: 'c1',
                name: 'Docker',
                description: 'Edit by B',
                sourceDocumentId: 'doc1',
              ),
            ],
          ),
        );
        await repoC.save(
          KnowledgeGraph(
            concepts: [
              Concept(
                id: 'c1',
                name: 'Docker',
                description: 'Edit by C',
                sourceDocumentId: 'doc1',
              ),
            ],
          ),
        );

        final fromA = await repoA.getChangeset(modifiedAfter: '');
        final fromB = await repoB.getChangeset(modifiedAfter: '');
        final fromC = await repoC.getChangeset(modifiedAfter: '');

        // Apply in different orders to each device
        await repoA.mergeChangeset(fromB);
        await repoA.mergeChangeset(fromC);

        await repoB.mergeChangeset(fromC);
        await repoB.mergeChangeset(fromA);

        await repoC.mergeChangeset(fromA);
        await repoC.mergeChangeset(fromB);

        // All should converge — C's edit wins (newest HLC)
        final loadA = await repoA.load();
        final loadB = await repoB.load();
        final loadC = await repoC.load();

        expect(loadA.concepts.first.description, 'Edit by C');
        expect(loadB.concepts.first.description, 'Edit by C');
        expect(loadC.concepts.first.description, 'Edit by C');
      },
    );
  });

  // -------------------------------------------------------------------------
  // Error paths
  // -------------------------------------------------------------------------

  group('error paths', () {
    test('mergeChangeset without HlcManager throws StateError', () async {
      final repoNoHlc = DriftGraphRepository(db: dbA);

      await repoA.save(fullGraph());
      final changeset = await repoA.getChangeset(modifiedAfter: '');

      expect(
        () => repoNoHlc.mergeChangeset(changeset),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('HlcManager'),
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // purgeTombstones + merge interaction
  // -------------------------------------------------------------------------

  group('purgeTombstones + merge', () {
    test('purged tombstones on A do not block modified rows from B', () async {
      // Both devices start with c1
      await repoA.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Original',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );
      final seed = await repoA.getChangeset(modifiedAfter: '');
      await repoB.mergeChangeset(seed);

      // A tombstones c1 (save empty graph → orphan tombstoning)
      await repoA.save(KnowledgeGraph());

      // A purges tombstones (physically deletes them)
      final purged = await repoA.purgeTombstones(
        before: '9999-12-31T23:59:59.999Z-FFFF-future',
      );
      expect(purged, greaterThan(0));

      // Verify c1 is physically gone from A's DB
      final rawA = await dbA.select(dbA.driftConcepts).get();
      expect(rawA.where((c) => c.id == 'c1'), isEmpty);

      // B modifies c1 (stamps it with B's HLC — no longer A's echo)
      await repoB.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'Docker',
              description: 'Updated by B',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      // B syncs to A — B's modified c1 has B's HLC, passes same-node guard
      final fromB = await repoB.getChangeset(modifiedAfter: '');
      await repoA.mergeChangeset(fromB);

      // A should have c1 again (B's version wins over absence)
      final loadA = await repoA.load();
      expect(loadA.concepts.any((c) => c.id == 'c1'), isTrue);
      expect(
        loadA.concepts.firstWhere((c) => c.id == 'c1').description,
        'Updated by B',
      );
    });

    test(
      'unmodified rows with original HLC are skipped by same-node guard',
      () async {
        // This documents a known behavior: if B holds an unmodified copy
        // of A's data (still carrying A's HLC), and A purges the tombstone,
        // B's changeset is filtered by A's same-node guard. This is correct
        // — purgeTombstones should only be called after all peers confirmed
        // receipt of the tombstone.
        await repoA.save(
          KnowledgeGraph(
            concepts: [
              Concept(
                id: 'c1',
                name: 'Docker',
                description: 'Original',
                sourceDocumentId: 'doc1',
              ),
            ],
          ),
        );
        final seed = await repoA.getChangeset(modifiedAfter: '');
        await repoB.mergeChangeset(seed);

        // A tombstones + purges c1
        await repoA.save(KnowledgeGraph());
        await repoA.purgeTombstones(
          before: '9999-12-31T23:59:59.999Z-FFFF-future',
        );

        // B still has unmodified c1 (with A's original HLC)
        final fromB = await repoB.getChangeset(modifiedAfter: '');
        final written = await repoA.mergeChangeset(fromB);

        // Same-node guard skips B's copy — it still carries A's HLC
        expect(written, 0);
        final loadA = await repoA.load();
        expect(loadA.concepts, isEmpty);
      },
    );
  });

  // -------------------------------------------------------------------------
  // maxHlc
  // -------------------------------------------------------------------------

  group('maxHlc', () {
    test('returns empty string for empty changeset', () {
      const changeset = GraphChangeset();
      expect(changeset.maxHlc, isEmpty);
    });

    test('returns the highest HLC across all tables', () async {
      // Save graph with multiple entities — each gets the same HLC from save()
      await repoA.save(fullGraph());
      final afterSave = await repoA.getLastModified();

      // Update a single quiz item — stamps a newer HLC
      final updated = testQuizItem(id: 'q1', conceptId: 'c1', difficulty: 6.0);
      await repoA.updateQuizItem(await repoA.load(), updated);

      final changeset = await repoA.getChangeset(modifiedAfter: '');

      // maxHlc should equal the quiz item's newer HLC (from updateQuizItem)
      final quizHlc = changeset.quizItems.firstWhere((q) => q.id == 'q1').hlc;
      expect(changeset.maxHlc, quizHlc);
      expect(changeset.maxHlc.compareTo(afterSave), greaterThan(0));
    });

    test('works with single-table changeset', () async {
      await repoA.save(fullGraph());
      final afterSave = await repoA.getLastModified();

      // Update only a quiz item
      final updated = testQuizItem(id: 'q1', conceptId: 'c1', difficulty: 7.0);
      await repoA.updateQuizItem(await repoA.load(), updated);

      // Get only the incremental changeset (just the quiz item)
      final changeset = await repoA.getChangeset(modifiedAfter: afterSave);
      expect(changeset.quizItems.length, 1);
      expect(changeset.concepts, isEmpty);
      expect(changeset.maxHlc, changeset.quizItems.first.hlc);
    });
  });

  // -------------------------------------------------------------------------
  // Schema migration v2 → v3
  // -------------------------------------------------------------------------

  group('schema migration', () {
    test('fresh v3 DB has HLC indexes and sync metadata table', () async {
      // Fresh DB goes through onCreate → createAll, which creates
      // @TableIndex annotations. Verify all 6 HLC indexes exist.
      final result =
          await dbA
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='index' "
                "AND name LIKE 'idx_%_hlc'",
              )
              .get();

      final indexNames = result.map((r) => r.data['name'] as String).toSet();
      expect(
        indexNames,
        containsAll([
          'idx_drift_concepts_hlc',
          'idx_drift_relationships_hlc',
          'idx_drift_quiz_items_hlc',
          'idx_drift_documents_hlc',
          'idx_drift_topics_hlc',
          'idx_drift_topic_documents_hlc',
        ]),
      );

      // Verify sync metadata table exists
      final tables =
          await dbA
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='drift_sync_metadata'",
              )
              .get();
      expect(tables.length, 1);
    });
  });
}
