import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend.dart';

/// Firestore operations for social features: wiki groups and friends.
class SocialRepository {
  SocialRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  // --- Wiki Groups ---

  /// Join a wiki group so other users with the same wiki can discover you.
  Future<void> joinWikiGroup({
    required String wikiUrlHash,
    required String displayName,
    String? photoUrl,
  }) async {
    await _firestore
        .collection('wikiGroups')
        .doc(wikiUrlHash)
        .collection('members')
        .doc(_userId)
        .set({
      'uid': _userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'joinedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// List all members of a wiki group.
  Stream<List<Friend>> watchWikiGroupMembers(String wikiUrlHash) {
    return _firestore
        .collection('wikiGroups')
        .doc(wikiUrlHash)
        .collection('members')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.id != _userId) // exclude self
            .map((doc) => Friend.fromJson(doc.data()))
            .toList());
  }

  // --- Friends ---

  /// Add a friend to the current user's friends list.
  Future<void> addFriend(Friend friend) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('friends')
        .doc(friend.uid)
        .set(friend.toJson());
  }

  /// Get all friends.
  Stream<List<Friend>> watchFriends() {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('friends')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Friend.fromJson(doc.data())).toList());
  }
}
