import 'package:engram/src/crdt/firestore_sync_transport.dart';
import 'package:engram/src/crdt/graph_changeset.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSyncTransport transport;

  const userId = 'test-user';
  const localNodeId = 'device-A';
  const remoteNodeId = 'device-B';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    transport = FirestoreSyncTransport(firestore: firestore, userId: userId);
  });

  /// Creates a minimal changeset with a single concept and the given HLC.
  GraphChangeset changesetWithHlc(
    String hlc, {
    String conceptId = 'c1',
    String description = 'Test concept',
  }) {
    return GraphChangeset(
      concepts: [
        DriftConcept(
          id: conceptId,
          name: 'Test',
          description: description,
          sourceDocumentId: 'doc1',
          tags: const IListConst([]),
          hlc: hlc,
          isDeleted: false,
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> logEntries() async {
    final docs =
        await firestore
            .collection('users')
            .doc(userId)
            .collection('sync_log_v2')
            .orderBy('seq')
            .get();
    return [for (final d in docs.docs) d.data()];
  }

  group('pushChangeset', () {
    test('writes a numbered entry', () async {
      final changeset = changesetWithHlc(
        '2026-01-01T00:00:00.000Z-0000-device-A',
      );

      await transport.pushChangeset(changeset: changeset, nodeId: localNodeId);

      final entries = await logEntries();
      expect(entries.length, 1);
      expect(entries.first['seq'], 1);
      expect(entries.first['nodeId'], localNodeId);
      expect(entries.first['maxHlc'], changeset.maxHlc);
      expect(entries.first['changeset'], isA<Map<String, dynamic>>());
    });

    test('numbers entries in push order, across devices', () async {
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-03-01T00:00:00.000Z-0000-device-B'),
        nodeId: remoteNodeId,
      );
      // An older clock pushed later still gets the later number.
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-A'),
        nodeId: localNodeId,
      );

      final entries = await logEntries();
      expect(
        [for (final e in entries) (e['seq'], e['nodeId'])],
        [(1, remoteNodeId), (2, localNodeId)],
      );
    });

    test('skips empty changeset', () async {
      await transport.pushChangeset(
        changeset: const GraphChangeset(),
        nodeId: localNodeId,
      );

      expect(await logEntries(), isEmpty);
    });

    test('splits a changeset larger than one entry may hold', () async {
      final small = FirestoreSyncTransport(
        firestore: firestore,
        userId: userId,
        maxEntryBytes: 400,
      );
      final big = GraphChangeset(
        concepts: [
          for (var i = 0; i < 5; i++)
            ...changesetWithHlc(
              '2026-01-01T00:00:00.000Z-000$i-device-B',
              conceptId: 'c$i',
              description: 'x' * 200,
            ).concepts,
        ],
      );

      await small.pushChangeset(changeset: big, nodeId: remoteNodeId);

      final entries = await logEntries();
      expect(entries.length, greaterThan(1));
      final pulled = await small.pullChangesets(afterSeq: 0);
      expect(
        {
          for (final c in pulled.changesets)
            for (final concept in c.concepts) concept.id,
        },
        {'c0', 'c1', 'c2', 'c3', 'c4'},
      );
    });
  });

  group('pullChangesets', () {
    test('returns changesets from other devices', () async {
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-B'),
        nodeId: remoteNodeId,
      );

      final results = await transport.pullChangesets(afterSeq: 0);

      expect(results.changesets.length, 1);
      expect(results.changesets.first.concepts.length, 1);
      expect(results.lastSeq, 1);
    });

    test('includes every device\'s entries, in log order', () async {
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-02T00:00:00.000Z-0000-device-B'),
        nodeId: remoteNodeId,
      );
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-A'),
        nodeId: localNodeId,
      );

      final results = await transport.pullChangesets(afterSeq: 0);

      expect(
        [for (final c in results.changesets) c.maxHlc],
        [
          '2026-01-02T00:00:00.000Z-0000-device-B',
          '2026-01-01T00:00:00.000Z-0000-device-A',
        ],
      );
      expect(results.lastSeq, 2);
    });

    test('returns only entries after the bookmark', () async {
      await transport.pushChangeset(
        changeset: changesetWithHlc(
          '2026-02-01T00:00:00.000Z-0000-device-B',
          conceptId: 'c1',
        ),
        nodeId: remoteNodeId,
      );
      // Pushed later with an older clock, as an offline device would.
      await transport.pushChangeset(
        changeset: changesetWithHlc(
          '2026-01-01T00:00:00.000Z-0000-device-C',
          conceptId: 'c2',
        ),
        nodeId: 'device-C',
      );

      final results = await transport.pullChangesets(afterSeq: 1);

      expect(results.changesets.single.concepts.single.id, 'c2');
      expect(results.lastSeq, 2);
    });

    test(
      'returns nothing and keeps the bookmark when the log is empty',
      () async {
        final results = await transport.pullChangesets(afterSeq: 7);
        expect(results.changesets, isEmpty);
        expect(results.lastSeq, 7);
      },
    );
  });

  group('the counter', () {
    test('continues from a count stored as a whole double', () async {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('sync_state')
          .doc('log')
          .set({'lastSeq': 4.0});

      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-A'),
        nodeId: localNodeId,
      );

      expect((await logEntries()).single['seq'], 5);
    });

    test('refuses to push over a counter it cannot read', () async {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('sync_state')
          .doc('log')
          .set({'lastSeq': 'garbled'});

      await expectLater(
        transport.pushChangeset(
          changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-A'),
          nodeId: localNodeId,
        ),
        throwsStateError,
      );
      expect(await logEntries(), isEmpty);
    });
  });

  group('unreadable entries', () {
    test('an unreadable entry holds the bookmark but not the entries after '
        'it', () async {
      await transport.pushChangeset(
        changeset: changesetWithHlc(
          '2026-01-01T00:00:00.000Z-0000-device-B',
          conceptId: 'before',
        ),
        nodeId: remoteNodeId,
      );
      final bad = await firestore
          .collection('users')
          .doc(userId)
          .collection('sync_log_v2')
          .add({'seq': 2, 'nodeId': remoteNodeId, 'changeset': 'garbled'});
      await firestore
          .collection('users')
          .doc(userId)
          .collection('sync_state')
          .doc('log')
          .set({'lastSeq': 2});
      await transport.pushChangeset(
        changeset: changesetWithHlc(
          '2026-01-02T00:00:00.000Z-0000-device-B',
          conceptId: 'after',
        ),
        nodeId: remoteNodeId,
      );

      final pulled = await transport.pullChangesets(afterSeq: 0);

      expect(
        [for (final c in pulled.changesets) c.concepts.single.id],
        ['before', 'after'],
      );
      expect(pulled.lastSeq, 1);
      expect(pulled.unreadable, [bad.id]);
    });

    test('a changeset with loosely typed nested maps is read', () async {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('sync_log_v2')
          .add({
            'seq': 1,
            'nodeId': remoteNodeId,
            'changeset': <Object?, Object?>{
              'drift_concepts': [
                <Object?, Object?>{
                  'id': 'c1',
                  'name': 'n',
                  'description': 'd',
                  'source_document_id': 'doc1',
                  'tags': '[]',
                  'parent_concept_id': null,
                  'embedding': null,
                  'hlc': '2026-01-01T00:00:00.000Z-0000-device-B',
                  'is_deleted': 0,
                },
              ],
            },
          });

      final pulled = await transport.pullChangesets(afterSeq: 0);
      expect(pulled.changesets.single.concepts.single.id, 'c1');
    });
  });

  group('round-trip', () {
    test('push then pull preserves changeset data', () async {
      final original = GraphChangeset(
        concepts: [
          DriftConcept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
            tags: IList(const ['devops']),
            hlc: '2026-01-15T10:00:00.000Z-0001-device-B',
            isDeleted: false,
          ),
        ],
        relationships: [
          const DriftRelationship(
            id: 'r1',
            fromConceptId: 'c1',
            toConceptId: 'c2',
            label: 'depends on',
            type: RelationshipType.prerequisite,
            hlc: '2026-01-15T10:00:00.000Z-0001-device-B',
            isDeleted: false,
          ),
        ],
      );

      await transport.pushChangeset(changeset: original, nodeId: remoteNodeId);

      final pulled = await transport.pullChangesets(afterSeq: 0);

      expect(pulled.changesets.length, 1);
      final restored = pulled.changesets.first;
      expect(restored.concepts.length, 1);
      expect(restored.concepts.first.name, 'Docker');
      expect(restored.concepts.first.tags.toList(), ['devops']);
      expect(restored.relationships.length, 1);
      expect(restored.relationships.first.label, 'depends on');
    });
  });
}
