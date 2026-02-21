import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Firestore CRUD for `users/{uid}/profile/main`.
class UserProfileRepository {
  UserProfileRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  DocumentReference get _profileDoc => _firestore
      .collection('users')
      .doc(_userId)
      .collection('profile')
      .doc('main');

  Future<UserProfile?> load() async {
    final snap = await _profileDoc.get();
    if (!snap.exists) return null;
    return UserProfile.fromJson(snap.data()! as Map<String, dynamic>);
  }

  Future<void> save(UserProfile profile) async {
    await _profileDoc.set(profile.toJson());
  }

  Future<void> updateWikiUrl(String wikiUrl) async {
    await _profileDoc.update({'wikiUrl': wikiUrl});
  }

  Future<void> updateLastSession({
    required String timestamp,
    required int streak,
  }) async {
    await _profileDoc.update({
      'lastSessionAt': timestamp,
      'currentStreak': streak,
    });
  }

  Stream<UserProfile?> watch() {
    return _profileDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromJson(snap.data()! as Map<String, dynamic>);
    });
  }
}
