import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/drift/drift_graph_repository.dart';
import '../storage/drift/engram_database.dart';
import '../storage/firestore_graph_repository.dart' show FirestoreGraphLoader;
import '../storage/graph_repository.dart';
import 'auth_provider.dart';
import 'crdt_sync_provider.dart';

/// Provides the singleton [EngramDatabase] instance.
///
/// Must be overridden in `main()` with an eagerly-created database:
/// ```dart
/// engramDatabaseProvider.overrideWithValue(EngramDatabase())
/// ```
final engramDatabaseProvider = Provider<EngramDatabase>(
  (_) => throw UnimplementedError('Override in main with actual database'),
);

/// Provides the active [GraphRepository] implementation.
///
/// Always returns [DriftGraphRepository] — local SQLite is the sole source
/// of truth. Remote sync is handled by [CrdtSyncNotifier] via the Firestore
/// `sync_log` changeset transport (see `crdt_sync_provider.dart`).
///
/// For pre-sync users who have data only in Firestore subcollections, call
/// [seedFromFirestoreIfNeeded] once at graph load time.
final graphRepositoryProvider = Provider<GraphRepository>((ref) {
  return ref.watch(driftGraphRepositoryProvider);
});

/// One-time Firestore → Drift seed for pre-sync users.
///
/// If the local Drift database is empty and the user is authenticated,
/// loads data from the legacy Firestore subcollections
/// (`users/{uid}/data/graph/`) and persists it to Drift. This bridges
/// users who have data from before the CRDT sync migration.
///
/// Safe to call multiple times — tracks seeding state internally and
/// short-circuits after the first attempt (even if it fails).
Future<void> seedFromFirestoreIfNeeded(Ref ref) async {
  // Only seed for authenticated users who might have Firestore data.
  final user = ref.read(authStateProvider).valueOrNull;
  if (user == null) return;

  final driftRepo = ref.read(driftGraphRepositoryProvider);
  final localGraph = await driftRepo.load();

  final isEmpty =
      localGraph.concepts.isEmpty &&
      localGraph.relationships.isEmpty &&
      localGraph.quizItems.isEmpty &&
      localGraph.documentMetadata.isEmpty;

  if (!isEmpty) return;

  try {
    final firestore = ref.read(firestoreProvider);
    final firestoreLoader = FirestoreGraphLoader(
      firestore: firestore,
      userId: user.uid,
    );
    final remoteGraph = await firestoreLoader.load();

    final remoteIsEmpty =
        remoteGraph.concepts.isEmpty &&
        remoteGraph.relationships.isEmpty &&
        remoteGraph.quizItems.isEmpty &&
        remoteGraph.documentMetadata.isEmpty;

    if (!remoteIsEmpty) {
      await driftRepo.save(remoteGraph);
      debugPrint(
        '[GraphStore] Seeded Drift from Firestore '
        '(${remoteGraph.concepts.length} concepts)',
      );
    }
  } on Exception catch (e) {
    debugPrint('[GraphStore] Firestore seed failed: $e');
  }
}
