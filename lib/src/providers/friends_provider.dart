import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    firestore: FirebaseFirestore.instance,
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
/// On initialization, hashes the user's wiki URL, joins the wiki group,
/// and watches for new members to auto-populate the friends list.
final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, List<Friend>>(FriendsNotifier.new);

class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return [];

    // Get the user's wiki URL from settings
    final config = ref.watch(settingsProvider);
    if (config.outlineApiUrl.isEmpty) return [];

    // Join the wiki group
    final wikiHash = hashWikiUrl(config.outlineApiUrl);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile != null) {
      await socialRepo.joinWikiGroup(
        wikiUrlHash: wikiHash,
        displayName: profile.displayName,
        photoUrl: profile.photoUrl,
      );
    }

    // Watch wiki group members and auto-add as friends
    final membersSubscription =
        socialRepo.watchWikiGroupMembers(wikiHash).listen((members) async {
      for (final member in members) {
        await socialRepo.addFriend(member);
      }
      // Trigger a rebuild to pick up new friends
      ref.invalidateSelf();
    });

    // Clean up subscription when provider is disposed
    ref.onDispose(membersSubscription.cancel);

    // Return current friends list
    final friendsStream = socialRepo.watchFriends();
    return await friendsStream.first;
  }
}
