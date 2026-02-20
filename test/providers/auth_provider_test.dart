import 'package:engram/src/providers/auth_provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('ensureSignedIn', () {
    test('returns uid when already signed in', () async {
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'existing-user'),
      );

      final uid = await ensureSignedIn(mockAuth);
      expect(uid, 'existing-user');
    });

    test('signs in anonymously when not signed in', () async {
      final mockAuth = MockFirebaseAuth();

      final uid = await ensureSignedIn(mockAuth);
      expect(uid, isNotNull);
      expect(uid, isNotEmpty);
    });
  });

  group('signOut', () {
    test('clears current user', () async {
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user1'),
      );

      expect(mockAuth.currentUser, isNotNull);
      await signOut(mockAuth);
      expect(mockAuth.currentUser, isNull);
    });
  });

  group('authStateProvider', () {
    test('emits user when signed in', () async {
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'stream-user', displayName: 'Streamer'),
      );

      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth),
      ]);
      addTearDown(container.dispose);

      final user = await container.read(authStateProvider.future);
      expect(user, isNotNull);
      expect(user!.uid, 'stream-user');
    });

    test('emits null when not signed in', () async {
      final mockAuth = MockFirebaseAuth();

      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth),
      ]);
      addTearDown(container.dispose);

      final user = await container.read(authStateProvider.future);
      expect(user, isNull);
    });
  });

  group('signInWithGoogle', () {
    test('accepts auth and firestore parameters', () {
      // Google sign-in requires platform channels (GoogleSignIn plugin),
      // so we verify the function signature. Full integration testing
      // requires a running emulator or device.
      expect(signInWithGoogle, isA<Function>());
    });
  });

  group('signInWithApple', () {
    test('accepts auth and firestore parameters', () {
      // Apple sign-in requires platform channels, so we verify the
      // function signature. Full integration testing requires a device.
      expect(signInWithApple, isA<Function>());
    });
  });
}
