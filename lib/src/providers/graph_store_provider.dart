import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/firestore_graph_repository.dart';
import '../storage/graph_repository.dart';
import '../storage/local_graph_repository.dart';
import 'settings_provider.dart';

/// Provides the active [GraphRepository] implementation.
/// Returns [FirestoreGraphRepository] when cloud sync is enabled and
/// user is signed in; otherwise returns [LocalGraphRepository].
final graphRepositoryProvider = Provider<GraphRepository>((ref) {
  final config = ref.watch(settingsProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);

  if (settingsRepo.getUseFirestore()) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirestoreGraphRepository(
        firestore: FirebaseFirestore.instance,
        userId: user.uid,
      );
    }
  }

  return LocalGraphRepository(dataDir: config.dataDir);
});

/// Backward-compatible alias so existing code referencing
/// [graphStoreProvider] continues to compile during migration.
@Deprecated('Use graphRepositoryProvider instead')
final graphStoreProvider = graphRepositoryProvider;
