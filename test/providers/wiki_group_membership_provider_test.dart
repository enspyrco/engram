import 'dart:async';

import 'package:engram/src/models/user_profile.dart';
import 'package:engram/src/providers/auth_provider.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/providers/user_profile_provider.dart';
import 'package:engram/src/providers/wiki_group_membership_provider.dart';
import 'package:engram/src/storage/config.dart';
import 'package:engram/src/storage/settings_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _MockUser extends Mock implements User {
  _MockUser({required this.uid});

  @override
  final String uid;
}

final _testProfile = UserProfile(
  uid: 'user1',
  displayName: 'Alice',
  photoUrl: 'https://photo.url/alice.jpg',
  currentStreak: 0,
  createdAt: DateTime.utc(2025),
);

/// Waits for a [FutureProvider] to reach a data or error state.
Future<T?> waitForProvider<T>(
  ProviderContainer container,
  FutureProvider<T?> provider,
) async {
  final completer = Completer<T?>();
  container.listen<AsyncValue<T?>>(provider, (previous, next) {
    next.when(
      data: (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      error: (e, s) {
        if (!completer.isCompleted) completer.completeError(e, s);
      },
      loading: () {},
    );
  }, fireImmediately: true);
  return completer.future;
}

void main() {
  group('wikiGroupMembershipProvider', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    Future<ProviderContainer> createContainer({
      User? user,
      String outlineApiUrl = 'https://kb.example.com',
      UserProfile? profile,
      bool useDefaultProfile = true,
      bool friendDiscoveryEnabled = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = SettingsRepository(prefs);
      if (friendDiscoveryEnabled) {
        await settingsRepo.setFriendDiscoveryEnabled(true);
      }

      final effectiveProfile =
          profile ?? (useDefaultProfile ? _testProfile : null);
      final container = ProviderContainer(
        overrides: [
          // Override with streams. Use waitForProvider to await settled state.
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          firestoreProvider.overrideWithValue(fakeFirestore),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          settingsProvider.overrideWith(
            () => _FixedSettingsNotifier(
              EngramConfig(outlineApiUrl: outlineApiUrl),
            ),
          ),
          userProfileProvider.overrideWith(
            (ref) => Stream.value(effectiveProfile),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns null when no user is signed in', () async {
      final container = await createContainer(user: null);
      final result = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );
      expect(result, isNull);
    });

    test('returns null when outline URL is empty', () async {
      final container = await createContainer(
        user: _MockUser(uid: 'user1'),
        outlineApiUrl: '',
      );
      final result = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );
      expect(result, isNull);
    });

    test('returns null when profile is not yet loaded', () async {
      final container = await createContainer(
        user: _MockUser(uid: 'user1'),
        useDefaultProfile: false,
      );
      final result = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );
      expect(result, isNull);
    });

    test('returns null when friend discovery is disabled', () async {
      final container = await createContainer(
        user: _MockUser(uid: 'user1'),
        friendDiscoveryEnabled: false,
      );
      final result = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );
      expect(result, isNull);
    });

    test('returns wiki hash after successful joinWikiGroup', () async {
      final container = await createContainer(user: _MockUser(uid: 'user1'));

      final result = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );

      expect(result, isNotNull);
      expect(result, hashWikiUrl('https://kb.example.com'));
      expect(result!.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);

      // Verify the membership doc was written
      final doc =
          await fakeFirestore
              .collection('wikiGroups')
              .doc(result)
              .collection('members')
              .doc('user1')
              .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Alice');
    });

    test('idempotent: calling twice does not error', () async {
      final container = await createContainer(user: _MockUser(uid: 'user1'));

      final hash1 = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );
      // Invalidate and re-read to simulate rebuild
      container.invalidate(wikiGroupMembershipProvider);
      final hash2 = await waitForProvider(
        container,
        wikiGroupMembershipProvider,
      );

      expect(hash1, hash2);
    });
  });

  group('normalizeWikiUrl', () {
    test('trims whitespace', () {
      expect(
        normalizeWikiUrl('  https://wiki.example.com  '),
        'wiki.example.com',
      );
    });

    test('lowercases', () {
      expect(normalizeWikiUrl('https://Wiki.EXAMPLE.com'), 'wiki.example.com');
    });

    test('strips trailing slashes', () {
      expect(
        normalizeWikiUrl('https://wiki.example.com///'),
        'wiki.example.com',
      );
    });

    test('strips http scheme', () {
      expect(normalizeWikiUrl('http://wiki.example.com'), 'wiki.example.com');
    });

    test('strips https scheme', () {
      expect(normalizeWikiUrl('https://wiki.example.com'), 'wiki.example.com');
    });
  });

  group('hashWikiUrl', () {
    test('normalizes URL before hashing', () {
      final hash1 = hashWikiUrl('https://Wiki.Example.com/');
      final hash2 = hashWikiUrl('https://wiki.example.com');
      final hash3 = hashWikiUrl('  https://wiki.example.com//  ');

      expect(hash1, hash2);
      expect(hash2, hash3);
    });

    test('http and https produce the same hash', () {
      final hash1 = hashWikiUrl('http://wiki.example.com');
      final hash2 = hashWikiUrl('https://wiki.example.com');

      expect(hash1, hash2);
    });

    test('http and https with trailing slash produce the same hash', () {
      final hash1 = hashWikiUrl('http://wiki.example.com/');
      final hash2 = hashWikiUrl('https://wiki.example.com/');
      final hash3 = hashWikiUrl('https://Wiki.Example.com');

      expect(hash1, hash2);
      expect(hash2, hash3);
    });

    test('different URLs produce different hashes', () {
      final hash1 = hashWikiUrl('https://wiki.alpha.com');
      final hash2 = hashWikiUrl('https://wiki.beta.com');

      expect(hash1, isNot(hash2));
    });

    test('returns 64-char hex string (SHA-256)', () {
      final hash = hashWikiUrl('https://wiki.test.com');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });
  });
}

/// A fixed [SettingsNotifier] that returns a pre-configured [EngramConfig].
class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier(this._config);
  final EngramConfig _config;

  @override
  EngramConfig build() => _config;
}
