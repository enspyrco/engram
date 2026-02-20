import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friend.dart';
import '../storage/social_repository.dart';
import 'auth_provider.dart';
import 'wiki_group_membership_provider.dart';

/// Provides the [SocialRepository] for the current user.
final socialRepositoryProvider = Provider<SocialRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  return SocialRepository(
    firestore: ref.watch(firestoreProvider),
    userId: user.uid,
  );
});

/// Manages friend discovery and the friends list.
///
/// Watches the user's friends subcollection directly. Wiki group membership
/// is handled by [wikiGroupMembershipProvider], which ensures `joinWikiGroup`
/// is called before any team or social provider starts listening.
final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, List<Friend>>(FriendsNotifier.new);

class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return [];

    // Wait for wiki group membership to be established
    final wikiHash = ref.watch(wikiGroupMembershipProvider).valueOrNull;
    if (wikiHash == null) return [];

    // Watch wiki group members and sync new ones to friends list
    final membersSubscription =
        socialRepo.watchWikiGroupMembers(wikiHash).listen((members) async {
      final currentFriends = state.valueOrNull ?? [];
      final currentUids = currentFriends.map((f) => f.uid).toSet();
      // Only write friends we haven't already added
      for (final member in members) {
        if (!currentUids.contains(member.uid)) {
          await socialRepo.addFriend(member);
        }
      }
    });
    ref.onDispose(membersSubscription.cancel);

    // Watch friends stream and update state directly (no invalidateSelf)
    final friendsSubscription =
        socialRepo.watchFriends().listen((friends) {
      state = AsyncData(friends);
    });
    ref.onDispose(friendsSubscription.cancel);

    // Return initial friends list
    return await socialRepo.watchFriends().first;
  }
}
