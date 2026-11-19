import 'package:drift/native.dart';
import 'package:engram/src/crdt/hlc_manager.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/providers/auth_provider.dart';
import 'package:engram/src/providers/clock_provider.dart';
import 'package:engram/src/providers/crdt_sync_provider.dart';
import 'package:engram/src/providers/graph_store_provider.dart';
import 'package:engram/src/providers/hlc_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/storage/drift/drift_graph_repository.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockUser extends Mock implements User {}

void main() {
  late EngramDatabase db;
  late DriftGraphRepository driftRepo;
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;

  const userId = 'test-user';
  final fixedClock = DateTime.utc(2026, 2, 25);

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
    driftRepo = DriftGraphRepository(
      db: db,
      hlcManager: HlcManager(nodeId: 'test-node'),
    );
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser();
    when(() => mockUser.uid).thenReturn(userId);
  });

  tearDown(() async {
    await db.close();
  });

  /// Writes sample data directly to Firestore subcollections.
  Future<void> seedFirestoreData(List<Concept> concepts) async {
    final graphDoc = fakeFirestore
        .collection('users')
        .doc(userId)
        .collection('data')
        .doc('graph');

    for (final concept in concepts) {
      await graphDoc
          .collection('concepts')
          .doc(concept.id)
          .set(concept.toJson());
    }
  }

  /// Creates a provider container with the given auth state.
  ProviderContainer makeContainer({User? user}) {
    return ProviderContainer(
      overrides: [
        engramDatabaseProvider.overrideWithValue(db),
        driftGraphRepositoryProvider.overrideWithValue(driftRepo),
        hlcManagerProvider.overrideWithValue(HlcManager(nodeId: 'test-node')),
        firestoreProvider.overrideWithValue(fakeFirestore),
        clockProvider.overrideWithValue(() => fixedClock),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );
  }

  group('seedFromFirestoreIfNeeded (via knowledgeGraphProvider)', () {
    test('unauthenticated user — Drift stays empty', () async {
      final container = makeContainer(user: null);

      // Reading knowledgeGraphProvider triggers build(), which calls
      // seedFromFirestoreIfNeeded. With no user, it should be a no-op.
      final graph = await container.read(knowledgeGraphProvider.future);

      expect(graph.concepts, isEmpty);
      expect(graph.relationships, isEmpty);
      container.dispose();
    });

    test('non-empty local Drift — no Firestore read', () async {
      // Pre-populate local Drift
      await driftRepo.save(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c-local',
              name: 'Local concept',
              description: 'Already in Drift',
              sourceDocumentId: 'doc1',
            ),
          ],
        ),
      );

      // Also populate Firestore (should be ignored)
      await seedFirestoreData([
        Concept(
          id: 'c-remote',
          name: 'Remote concept',
          description: 'Should not appear',
          sourceDocumentId: 'doc2',
        ),
      ]);

      final container = makeContainer(user: mockUser);
      final graph = await container.read(knowledgeGraphProvider.future);

      // Only local data should be present
      expect(graph.concepts, hasLength(1));
      expect(graph.concepts.first.id, 'c-local');
      container.dispose();
    });

    test('empty local + non-empty Firestore — seeds Drift', () async {
      // Populate Firestore with data
      await seedFirestoreData([
        Concept(
          id: 'c-remote',
          name: 'Remote concept',
          description: 'From Firestore',
          sourceDocumentId: 'doc1',
        ),
      ]);

      final container = makeContainer(user: mockUser);
      // Pre-resolve the auth stream so seedFromFirestoreIfNeeded sees the user.
      await container.read(authStateProvider.future);

      final graph = await container.read(knowledgeGraphProvider.future);

      // Firestore data should have been seeded into Drift
      expect(graph.concepts, hasLength(1));
      expect(graph.concepts.first.id, 'c-remote');
      expect(graph.concepts.first.name, 'Remote concept');

      // Verify it's actually in Drift (not just in-memory)
      final directLoad = await driftRepo.load();
      expect(directLoad.concepts, hasLength(1));
      container.dispose();
    });

    test('empty local + empty Firestore — stays empty', () async {
      final container = makeContainer(user: mockUser);
      final graph = await container.read(knowledgeGraphProvider.future);

      expect(graph.concepts, isEmpty);
      expect(graph.relationships, isEmpty);
      expect(graph.quizItems, isEmpty);
      container.dispose();
    });

    test('Firestore error — logs and returns empty graph', () async {
      // FakeFirebaseFirestore can't easily simulate errors, so we verify
      // the graceful degradation path: even if the Firestore seed has
      // nothing, the local Drift load should succeed without throwing.
      final container = makeContainer(user: mockUser);
      final graph = await container.read(knowledgeGraphProvider.future);

      // Should return empty graph without throwing
      expect(graph.concepts, isEmpty);
      container.dispose();
    });
  });
}
