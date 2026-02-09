import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Manages anonymous authentication for Firestore user isolation.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Signs in anonymously if not already signed in.
/// Returns the user ID for Firestore path construction.
Future<String?> ensureSignedIn(FirebaseAuth auth) async {
  if (auth.currentUser != null) {
    return auth.currentUser!.uid;
  }
  final credential = await auth.signInAnonymously();
  return credential.user?.uid;
}
