import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friend.dart';
import '../storage/social_repository.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'user_profile_provider.dart';

/// Provides the [SocialRepository] for the current user.
final socialRepositoryProvider = Provider<SocialRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  return SocialRepository(
    firestore: ref.watch(firestoreProvider),
    userId: user.uid,
  );
});

/// Normalizes a wiki URL for consistent hashing:
/// lowercase, trim whitespace, remove trailing slash.
String normalizeWikiUrl(String url) {
  return url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
}

/// SHA-256 hash of the normalized wiki URL, used as the wiki group key.
String hashWikiUrl(String url) {
  final normalized = normalizeWikiUrl(url);
  return sha256.convert(utf8.encode(normalized)).toString();
}

/// Manages friend discovery and the friends list.
///
/// Watches the user's friends subcollection directly. Wiki group joining
/// is handled as a one-shot side-effect, not on every rebuild.
final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, List<Friend>>(FriendsNotifier.new);

class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  bool _hasJoinedGroup = false;

  @override
  Future<List<Friend>> build() async {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return [];

    // Get the user's wiki URL from settings
    final config = ref.watch(settingsProvider);
    if (config.outlineApiUrl.isEmpty) return [];

    final wikiHash = hashWikiUrl(config.outlineApiUrl);

    // Join the wiki group once per provider lifecycle (not on every rebuild)
    if (!_hasJoinedGroup) {
      final profile = ref.watch(userProfileProvider).valueOrNull;
      if (profile != null) {
        await socialRepo.joinWikiGroup(
          wikiUrlHash: wikiHash,
          displayName: profile.displayName,
          photoUrl: profile.photoUrl,
        );
        _hasJoinedGroup = true;
      }
    }

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
