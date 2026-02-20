import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/social_repository.dart';
import 'auth_provider.dart';

/// Provides the [SocialRepository] for the current user.
final socialRepositoryProvider = Provider<SocialRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  return SocialRepository(
    firestore: ref.watch(firestoreProvider),
    userId: user.uid,
  );
});
