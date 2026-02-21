import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/firestore_graph_repository.dart';
import '../storage/graph_repository.dart';
import '../storage/local_graph_repository.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

/// Provides the active [GraphRepository] implementation.
/// Uses [FirestoreGraphRepository] when user is authenticated;
/// falls back to [LocalGraphRepository] for unauthenticated/offline use.
final graphRepositoryProvider = Provider<GraphRepository>((ref) {
  final config = ref.watch(settingsProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  final firestore = ref.watch(firestoreProvider);

  if (user != null) {
    return FirestoreGraphRepository(firestore: firestore, userId: user.uid);
  }

  return LocalGraphRepository(dataDir: config.dataDir);
});

/// Backward-compatible alias so existing code referencing
/// [graphStoreProvider] continues to compile during migration.
@Deprecated('Use graphRepositoryProvider instead')
final graphStoreProvider = graphRepositoryProvider;
