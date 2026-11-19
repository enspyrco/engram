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
  GraphChangeset changesetWithHlc(String hlc, {String conceptId = 'c1'}) {
    return GraphChangeset(
      concepts: [
        DriftConcept(
          id: conceptId,
          name: 'Test',
          description: 'Test concept',
          sourceDocumentId: 'doc1',
          tags: const IListConst([]),
          hlc: hlc,
          isDeleted: false,
        ),
      ],
    );
  }

  group('pushChangeset', () {
    test('writes changeset doc to sync_log', () async {
      final changeset = changesetWithHlc(
        '2026-01-01T00:00:00.000Z-0000-device-A',
      );

      await transport.pushChangeset(changeset: changeset, nodeId: localNodeId);

      final docs =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('sync_log')
              .get();
      expect(docs.docs.length, 1);

      final data = docs.docs.first.data();
      expect(data['nodeId'], localNodeId);
      expect(data['maxHlc'], changeset.maxHlc);
      expect(data['changeset'], isA<Map<String, dynamic>>());
    });

    test('skips empty changeset', () async {
      await transport.pushChangeset(
        changeset: const GraphChangeset(),
        nodeId: localNodeId,
      );

      final docs =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('sync_log')
              .get();
      expect(docs.docs, isEmpty);
    });
  });

  group('pullChangesets', () {
    test('returns changesets from other devices', () async {
      // Push from remote device
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-B'),
        nodeId: remoteNodeId,
      );

      final results = await transport.pullChangesets(
        sinceHlc: '',
        localNodeId: localNodeId,
      );

      expect(results.length, 1);
      expect(results.first.changeset.concepts.length, 1);
      expect(results.first.maxHlc, '2026-01-01T00:00:00.000Z-0000-device-B');
    });

    test('excludes own changesets', () async {
      // Push from local device
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-A'),
        nodeId: localNodeId,
      );
      // Push from remote device
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-02T00:00:00.000Z-0000-device-B'),
        nodeId: remoteNodeId,
      );

      final results = await transport.pullChangesets(
        sinceHlc: '',
        localNodeId: localNodeId,
      );

      // Should only see remote's changeset
      expect(results.length, 1);
      expect(results.first.maxHlc, '2026-01-02T00:00:00.000Z-0000-device-B');
    });

    test('filters by sinceHlc', () async {
      // Push two changesets from remote device
      await transport.pushChangeset(
        changeset: changesetWithHlc(
          '2026-01-01T00:00:00.000Z-0000-device-B',
          conceptId: 'c1',
        ),
        nodeId: remoteNodeId,
      );
      await transport.pushChangeset(
        changeset: changesetWithHlc(
          '2026-02-01T00:00:00.000Z-0000-device-B',
          conceptId: 'c2',
        ),
        nodeId: remoteNodeId,
      );

      // Pull only changes after the first changeset's HLC
      final results = await transport.pullChangesets(
        sinceHlc: '2026-01-01T00:00:00.000Z-0000-device-B',
        localNodeId: localNodeId,
      );

      expect(results.length, 1);
      expect(results.first.maxHlc, '2026-02-01T00:00:00.000Z-0000-device-B');
    });

    test('returns empty list when no remote changesets exist', () async {
      final results = await transport.pullChangesets(
        sinceHlc: '',
        localNodeId: localNodeId,
      );
      expect(results, isEmpty);
    });
  });

  group('cleanup', () {
    test('deletes entries with maxHlc <= threshold', () async {
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-01-01T00:00:00.000Z-0000-device-A'),
        nodeId: localNodeId,
      );
      await transport.pushChangeset(
        changeset: changesetWithHlc('2026-03-01T00:00:00.000Z-0000-device-B'),
        nodeId: remoteNodeId,
      );

      final deleted = await transport.cleanup(
        beforeHlc: '2026-02-01T00:00:00.000Z-0000-threshold',
      );

      expect(deleted, 1);

      // Only the newer entry should remain
      final remaining =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('sync_log')
              .get();
      expect(remaining.docs.length, 1);
      expect(
        remaining.docs.first.data()['maxHlc'],
        '2026-03-01T00:00:00.000Z-0000-device-B',
      );
    });

    test('returns 0 when nothing to clean up', () async {
      final deleted = await transport.cleanup(
        beforeHlc: '2026-01-01T00:00:00.000Z-0000-threshold',
      );
      expect(deleted, 0);
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

      final pulled = await transport.pullChangesets(
        sinceHlc: '',
        localNodeId: localNodeId,
      );

      expect(pulled.length, 1);
      final restored = pulled.first.changeset;
      expect(restored.concepts.length, 1);
      expect(restored.concepts.first.name, 'Docker');
      expect(restored.concepts.first.tags.toList(), ['devops']);
      expect(restored.relationships.length, 1);
      expect(restored.relationships.first.label, 'depends on');
    });
  });
}
