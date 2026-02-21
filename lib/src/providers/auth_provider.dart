import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_profile.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provides the [FirebaseFirestore] instance. Override in tests with
/// `fake_cloud_firestore` for testable Firestore operations.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Manages authentication state as a stream.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Provides the [GoogleSignIn] instance. Override in tests with a mock
/// to avoid platform channel errors and verify sign-in behavior.
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(scopes: ['email', 'profile']);
});

/// Signs in with Google. Returns the Firebase [User] or null on cancel.
///
/// Google always provides displayName, email, and photoUrl on every sign-in.
Future<User?> signInWithGoogle(
  FirebaseAuth auth, {
  required FirebaseFirestore firestore,
  required GoogleSignIn googleSignIn,
}) async {
  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) return null; // User cancelled

  final googleAuth = await googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  final userCredential = await auth.signInWithCredential(credential);
  final user = userCredential.user;
  if (user == null) return null;

  // Write profile to Firestore (idempotent — overwrites with latest data)
  await _writeProfile(
    firestore: firestore,
    uid: user.uid,
    displayName: googleUser.displayName ?? user.displayName ?? 'User',
    email: googleUser.email,
    photoUrl: googleUser.photoUrl,
  );
  return user;
}

/// Signs in with Apple. Returns the Firebase [User] or null on failure.
///
/// Apple only provides name + email on the FIRST sign-in. Subsequent
/// sign-ins return null for these fields. We capture and persist immediately.
Future<User?> signInWithApple(
  FirebaseAuth auth, {
  required FirebaseFirestore firestore,
}) async {
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.fullName,
      AppleIDAuthorizationScopes.email,
    ],
  );

  final oauthCredential = OAuthProvider('apple.com').credential(
    idToken: appleCredential.identityToken,
    accessToken: appleCredential.authorizationCode,
  );
  final userCredential = await auth.signInWithCredential(oauthCredential);
  final user = userCredential.user;
  if (user == null) return null;

  // Construct display name from Apple's given/family name (first sign-in only)
  final givenName = appleCredential.givenName;
  final familyName = appleCredential.familyName;
  String? appleName;
  if (givenName != null || familyName != null) {
    appleName = [givenName, familyName].whereType<String>().join(' ').trim();
  }

  // Apple never provides a photo URL.
  // CRITICAL: Apple only sends name on first sign-in. If this write fails,
  // the name is lost forever. Retry up to 2 times before giving up.
  final isFirstSignIn = appleName != null;
  var retries = isFirstSignIn ? 2 : 0;
  while (true) {
    try {
      await _writeProfile(
        firestore: firestore,
        uid: user.uid,
        displayName: appleName ?? user.displayName ?? 'User',
        email: appleCredential.email ?? user.email,
        photoUrl: null,
        onlyIfNew: !isFirstSignIn,
      );
      break;
    } catch (e) {
      if (retries > 0) {
        retries--;
        await Future<void>.delayed(const Duration(seconds: 1));
      } else {
        // Log but don't block sign-in — the user is already authenticated
        debugPrint(
          'CRITICAL: Failed to write Apple profile for ${user.uid}: $e',
        );
        break;
      }
    }
  }
  return user;
}

/// Ensures the user is signed in, falling back to anonymous auth.
///
/// Returns the user's UID, or null if sign-in failed.
final ensureSignedInProvider = FutureProvider<String?>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth.currentUser != null) return auth.currentUser!.uid;
  final credential = await auth.signInAnonymously();
  return credential.user?.uid;
});

/// Signs out the current user.
Future<void> signOut(FirebaseAuth auth) async {
  await auth.signOut();
}

/// Writes user profile to Firestore.
///
/// If [onlyIfNew] is true, only writes if the profile doc doesn't exist yet.
/// This prevents overwriting Apple name data on subsequent sign-ins where
/// Apple returns null for name fields.
Future<void> _writeProfile({
  required FirebaseFirestore firestore,
  required String uid,
  required String displayName,
  String? email,
  String? photoUrl,
  bool onlyIfNew = false,
  DateTime? now,
}) async {
  final docRef = firestore.collection('users').doc(uid);
  final profileRef = docRef.collection('profile').doc('main');

  if (onlyIfNew) {
    final existing = await profileRef.get();
    if (existing.exists) return;
  }

  final timestamp = now ?? DateTime.now().toUtc();
  final profile = UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    photoUrl: photoUrl,
    currentStreak: 0,
    createdAt: timestamp,
  );
  await profileRef.set(profile.toJson(), SetOptions(merge: true));
}
