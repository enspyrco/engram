import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../storage/user_profile_repository.dart';
import 'auth_provider.dart';

/// Provides the [UserProfileRepository] for the current signed-in user.
/// Returns null if no user is signed in.
final userProfileRepositoryProvider = Provider<UserProfileRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  return UserProfileRepository(
    firestore: ref.watch(firestoreProvider),
    userId: user.uid,
  );
});

/// Watches the current user's profile from Firestore.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watch();
});
