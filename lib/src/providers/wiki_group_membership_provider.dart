import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'settings_provider.dart';
import 'social_repository_provider.dart';
import 'user_profile_provider.dart';

/// Normalizes a wiki URL for consistent hashing:
/// trim whitespace, lowercase, strip trailing slashes, strip http(s) scheme.
String normalizeWikiUrl(String url) {
  var normalized = url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  normalized = normalized.replaceFirst(RegExp(r'^https?://'), '');
  return normalized;
}

/// SHA-256 hash of the normalized wiki URL, used as the wiki group key.
String hashWikiUrl(String url) {
  final normalized = normalizeWikiUrl(url);
  return sha256.convert(utf8.encode(normalized)).toString();
}

/// Ensures the current user has joined their wiki group before any team
/// provider starts watching Firestore collections that require membership.
///
/// Returns the wiki URL hash on success, or `null` if preconditions are not
/// met (no user, no outline URL, no profile, no social repository).
///
/// All team providers depend on this indirectly via [teamRepositoryProvider],
/// which watches this provider for the wiki hash. Since `joinWikiGroup` is
/// idempotent, calling it on every provider rebuild is safe.
final wikiGroupMembershipProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final config = ref.watch(settingsProvider);
  if (config.outlineApiUrl.isEmpty) return null;

  final socialRepo = ref.watch(socialRepositoryProvider);
  if (socialRepo == null) return null;

  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return null;

  final wikiHash = hashWikiUrl(config.outlineApiUrl);

  await socialRepo.joinWikiGroup(
    wikiUrlHash: wikiHash,
    displayName: profile.displayName,
    photoUrl: profile.photoUrl,
  );

  return wikiHash;
});
