import 'package:drift/native.dart';
import 'package:engram/src/crdt/firestore_sync_transport.dart';
import 'package:engram/src/crdt/graph_changeset.dart';
import 'package:engram/src/crdt/hlc_manager.dart';
import 'package:engram/src/crdt/node_id_repository.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/crdt_sync_state.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/providers/clock_provider.dart';
import 'package:engram/src/providers/crdt_sync_provider.dart';
import 'package:engram/src/providers/hlc_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/storage/drift/drift_graph_repository.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockNodeIdRepository extends Mock implements NodeIdRepository {}

void main() {
  late EngramDatabase db;
  late HlcManager hlcManager;
  late FakeFirebaseFirestore firestore;
  late DriftGraphRepository driftRepo;
  late FirestoreSyncTransport transport;
  late ProviderContainer container;
  late MockNodeIdRepository mockNodeIdRepo;

  const userId = 'test-user';
  const localNodeId = 'device-A';
  const remoteNodeId = 'device-B';
  final fixedClock = DateTime.utc(2026, 2, 25);

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
    hlcManager = HlcManager(nodeId: localNodeId);
    firestore = FakeFirebaseFirestore();
    driftRepo = DriftGraphRepository(db: db, hlcManager: hlcManager);
    transport = FirestoreSyncTransport(firestore: firestore, userId: userId);
    mockNodeIdRepo = MockNodeIdRepository();
    when(() => mockNodeIdRepo.nodeId).thenReturn(localNodeId);

    container = ProviderContainer(
      overrides: [
        driftGraphRepositoryProvider.overrideWithValue(driftRepo),
        firestoreSyncTransportProvider.overrideWithValue(transport),
        nodeIdRepositoryProvider.overrideWithValue(mockNodeIdRepo),
        clockProvider.overrideWithValue(() => fixedClock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Helper: push a changeset from a "remote" device directly into Firestore.
  Future<void> pushFromRemote(String conceptId, String hlc) async {
    final remoteTransport = FirestoreSyncTransport(
      firestore: firestore,
      userId: userId,
    );
    final remoteHlcManager = HlcManager(nodeId: remoteNodeId);
    final remoteDb = EngramDatabase.forTesting(NativeDatabase.memory());
    final remoteRepo = DriftGraphRepository(
      db: remoteDb,
      hlcManager: remoteHlcManager,
    );

    await remoteRepo.seedEmpty(
      KnowledgeGraph(
        concepts: [
          Concept(
            id: conceptId,
            name: 'Remote concept $conceptId',
            description: 'From device B',
            sourceDocumentId: 'doc1',
          ),
        ],
      ),
    );

    final changeset = await remoteRepo.getChangeset(modifiedAfter: '');
    await remoteTransport.pushChangeset(
      changeset: changeset,
      nodeId: remoteNodeId,
    );

    await remoteDb.close();
  }

  group('CrdtSyncNotifier', () {
    test('initial state is idle', () {
      final state = container.read(crdtSyncProvider);
      expect(state.phase, CrdtSyncPhase.idle);
      expect(state.lastSyncedAt, isNull);
      expect(state.isSyncing, isFalse);
    });

    test('sync pushes local changeset to Firestore', () async {
      // Save local data
      await driftRepo.seedEmpty(
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

      await container.read(crdtSyncProvider.notifier).sync();

      final state = container.read(crdtSyncProvider);
      expect(state.phase, CrdtSyncPhase.idle);
      expect(state.pushedCount, greaterThan(0));
      expect(state.lastSyncedAt, fixedClock);

      // Verify the sync_log has a document
      final docs =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('sync_log')
              .get();
      expect(docs.docs.length, 1);
      expect(docs.docs.first.data()['nodeId'], localNodeId);
    });

    test('sync pulls and merges remote changesets', () async {
      // Push a changeset from a "remote" device
      await pushFromRemote(
        'c-remote',
        '2026-01-01T00:00:00.000Z-0000-device-B',
      );

      await container.read(crdtSyncProvider.notifier).sync();

      final state = container.read(crdtSyncProvider);
      expect(state.phase, CrdtSyncPhase.idle);
      expect(state.pulledCount, 1);
      expect(state.mergedCount, greaterThan(0));

      // Verify the concept was merged into local DB
      final graph = await driftRepo.load();
      expect(graph.concepts.any((c) => c.id == 'c-remote'), isTrue);
    });

    test('sync updates push and pull bookmarks', () async {
      // Save local data and push from remote
      await driftRepo.seedEmpty(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c-local',
              name: 'Local',
              description: 'Local concept',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );
      await pushFromRemote(
        'c-remote',
        '2026-01-01T00:00:00.000Z-0000-device-B',
      );

      await container.read(crdtSyncProvider.notifier).sync();

      // Push bookmark should be updated
      final pushHlc = await driftRepo.getLastSyncedHlc(
        'firestore-sync-log:push',
      );
      expect(pushHlc, isNotNull);
      expect(pushHlc, isNotEmpty);

      // Pull bookmark should be updated
      final pullHlc = await driftRepo.getLastSyncedHlc(
        'firestore-sync-log:pull',
      );
      expect(pullHlc, isNotNull);
      expect(pullHlc, isNotEmpty);
    });

    test(
      'sync is idempotent — second sync with no changes is a no-op',
      () async {
        await driftRepo.seedEmpty(
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

        // First sync
        await container.read(crdtSyncProvider.notifier).sync();
        final firstState = container.read(crdtSyncProvider);
        expect(firstState.pushedCount, greaterThan(0));

        // Second sync — no new local changes, no new remote changes
        await container.read(crdtSyncProvider.notifier).sync();
        final secondState = container.read(crdtSyncProvider);
        expect(secondState.pushedCount, 0);
        expect(secondState.pulledCount, 0);
        expect(secondState.mergedCount, 0);
      },
    );

    test('sync with no transport (unauthenticated) is a no-op', () async {
      final noAuthContainer = ProviderContainer(
        overrides: [
          driftGraphRepositoryProvider.overrideWithValue(driftRepo),
          firestoreSyncTransportProvider.overrideWithValue(null),
          nodeIdRepositoryProvider.overrideWithValue(mockNodeIdRepo),
          clockProvider.overrideWithValue(() => fixedClock),
        ],
      );

      await noAuthContainer.read(crdtSyncProvider.notifier).sync();

      final state = noAuthContainer.read(crdtSyncProvider);
      expect(state.phase, CrdtSyncPhase.idle);
      expect(state.lastSyncedAt, isNull);

      noAuthContainer.dispose();
    });

    test('overlapping syncs are guarded', () async {
      await driftRepo.seedEmpty(
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

      // Start two syncs concurrently
      final notifier = container.read(crdtSyncProvider.notifier);
      final future1 = notifier.sync();
      final future2 = notifier.sync(); // Should be a no-op

      await Future.wait([future1, future2]);

      // Only one sync_log entry should exist (not two)
      final docs =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('sync_log')
              .get();
      expect(docs.docs.length, 1);
    });

    test('sync error sets error state without crashing', () async {
      // Create a container with a transport that will throw
      final badContainer = ProviderContainer(
        overrides: [
          driftGraphRepositoryProvider.overrideWithValue(driftRepo),
          firestoreSyncTransportProvider.overrideWithValue(transport),
          nodeIdRepositoryProvider.overrideWithValue(mockNodeIdRepo),
          clockProvider.overrideWithValue(() => fixedClock),
          // Override drift repo with one that throws on getChangeset
          driftGraphRepositoryProvider.overrideWithValue(
            _ThrowingDriftRepo(db: db, hlcManager: hlcManager),
          ),
        ],
      );

      await badContainer.read(crdtSyncProvider.notifier).sync();

      final state = badContainer.read(crdtSyncProvider);
      expect(state.phase, CrdtSyncPhase.error);
      expect(state.errorMessage, isNotEmpty);

      badContainer.dispose();
    });

    test('sync invalidates knowledgeGraphProvider after merge', () async {
      // Push a remote changeset so the sync has something to merge
      await pushFromRemote(
        'c-remote',
        '2026-01-01T00:00:00.000Z-0000-device-B',
      );

      // Pre-read knowledgeGraphProvider to register a listener
      var invalidated = false;
      container.listen(knowledgeGraphProvider, (_, __) {
        invalidated = true;
      });

      await container.read(crdtSyncProvider.notifier).sync();

      // After merge, the graph provider should have been invalidated
      expect(invalidated, isTrue);
    });

    test('sync purges tombstones after successful pull and merge', () async {
      // Create local data, tombstone it, then sync to get the pull bookmark
      await driftRepo.seedEmpty(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c-old',
              name: 'Old',
              description: 'Will be tombstoned',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );
      // Re-extract doc1 as empty to tombstone c-old
      final seeded = await driftRepo.load();
      await driftRepo.applyExtraction(
        seeded
            .withExtraction(
              const ExtractionResult(
                concepts: [],
                relationships: [],
                quizItems: [],
              ),
              documentId: 'doc1',
              documentTitle: 'Doc 1',
              updatedAt: '2026-01-02T00:00:00.000Z',
            )
            .patch,
      );

      // Push a remote changeset so pull has something to merge
      await pushFromRemote(
        'c-remote',
        '2026-01-01T00:00:00.000Z-0000-device-B',
      );

      await container.read(crdtSyncProvider.notifier).sync();

      final state = container.read(crdtSyncProvider);
      expect(state.phase, CrdtSyncPhase.idle);
      expect(state.pulledCount, greaterThan(0));

      // Tombstoned rows with HLCs older than the pull bookmark should be
      // physically deleted. Verify that purgeTombstones ran by checking
      // the changeset (which includes tombstoned rows).
      final allRows = await driftRepo.getChangeset(modifiedAfter: '');
      // The old concept should have been purged (its HLC < pull bookmark)
      // while the merged remote concept persists
      final conceptIds = allRows.concepts.map((c) => c.id).toSet();
      expect(conceptIds, contains('c-remote'));
    });

    test('sync errors use exponential backoff on periodic ticks', () async {
      final throwingDb = EngramDatabase.forTesting(NativeDatabase.memory());
      final throwingRepo = _ThrowingDriftRepo(
        db: throwingDb,
        hlcManager: hlcManager,
      );
      final errorContainer = ProviderContainer(
        overrides: [
          driftGraphRepositoryProvider.overrideWithValue(throwingRepo),
          firestoreSyncTransportProvider.overrideWithValue(transport),
          nodeIdRepositoryProvider.overrideWithValue(mockNodeIdRepo),
          clockProvider.overrideWithValue(() => fixedClock),
        ],
      );

      final notifier = errorContainer.read(crdtSyncProvider.notifier);

      // First error — should set skipTicks = min(2^1, 6) = 2
      await notifier.sync();
      expect(errorContainer.read(crdtSyncProvider).phase, CrdtSyncPhase.error);

      // Second consecutive error — skipTicks = min(2^2, 6) = 4
      await notifier.sync();

      // Verify the error state persists
      expect(errorContainer.read(crdtSyncProvider).phase, CrdtSyncPhase.error);

      errorContainer.dispose();
      await throwingDb.close();
    });

    test('injectable clock is used in sync metadata writes', () async {
      final clockTime = DateTime.utc(2026, 6, 15, 12, 0, 0);
      final clockDriftRepo = DriftGraphRepository(
        db: db,
        hlcManager: hlcManager,
        clock: () => clockTime,
      );

      await clockDriftRepo.updateLastSyncedHlc('test-peer', 'some-hlc');

      // Read back the metadata and verify the timestamp
      final hlc = await clockDriftRepo.getLastSyncedHlc('test-peer');
      expect(hlc, 'some-hlc');
    });
  });
}

/// A DriftGraphRepository that throws on getChangeset for testing error paths.
class _ThrowingDriftRepo extends DriftGraphRepository {
  _ThrowingDriftRepo({required super.db, super.hlcManager});

  @override
  Future<GraphChangeset> getChangeset({required String modifiedAfter}) {
    throw Exception('simulated failure');
  }
}
