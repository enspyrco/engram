import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/challenge.dart';
import '../models/detailed_mastery_snapshot.dart';
import '../models/friend.dart';
import '../models/nudge.dart';

/// Firestore operations for social features: wiki groups, friends,
/// challenges, and nudges.
class SocialRepository {
  SocialRepository({
    required FirebaseFirestore firestore,
    required String userId,
    DateTime Function()? clock,
  })  : _firestore = firestore,
        _userId = userId,
        _clock = clock ?? _defaultClock;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final FirebaseFirestore _firestore;
  final String _userId;
  final DateTime Function() _clock;

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
      'joinedAt': _clock().toIso8601String(),
    }, SetOptions(merge: true));
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

  // --- Detailed Mastery Snapshots ---

  /// Publish this user's per-concept mastery data for teammates to see.
  /// Written to the wiki group so all members can stream it.
  Future<void> writeDetailedMasterySnapshot({
    required String wikiUrlHash,
    required DetailedMasterySnapshot snapshot,
  }) async {
    await _firestore
        .collection('wikiGroups')
        .doc(wikiUrlHash)
        .collection('memberSnapshots')
        .doc(_userId)
        .set(snapshot.toJson());
  }

  /// Stream all team members' detailed mastery snapshots.
  Stream<Map<String, DetailedMasterySnapshot>> watchMemberSnapshots(
    String wikiUrlHash,
  ) {
    return _firestore
        .collection('wikiGroups')
        .doc(wikiUrlHash)
        .collection('memberSnapshots')
        .snapshots()
        .map((snapshot) {
      final result = <String, DetailedMasterySnapshot>{};
      for (final doc in snapshot.docs) {
        if (doc.id == _userId) continue; // exclude self
        result[doc.id] = DetailedMasterySnapshot.fromJson(doc.data());
      }
      return result;
    });
  }

  // --- Challenges ---

  /// Send a challenge to a friend.
  Future<void> sendChallenge(Challenge challenge) async {
    await _firestore
        .collection('social')
        .doc('challenges')
        .collection('items')
        .doc(challenge.id)
        .set(challenge.toJson());
  }

  /// Watch incoming challenges for the current user.
  Stream<List<Challenge>> watchIncomingChallenges() {
    return _firestore
        .collection('social')
        .doc('challenges')
        .collection('items')
        .where('toUid', isEqualTo: _userId)
        .where('status', isEqualTo: ChallengeStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromJson(doc.data()))
            .toList());
  }

  /// Update challenge status (accept, complete, decline).
  Future<void> updateChallengeStatus(
    String challengeId,
    ChallengeStatus status, {
    int? score,
  }) async {
    final data = <String, dynamic>{'status': status.name};
    if (score != null) data['score'] = score;
    await _firestore
        .collection('social')
        .doc('challenges')
        .collection('items')
        .doc(challengeId)
        .update(data);
  }

  // --- Nudges ---

  /// Send a nudge to a friend.
  Future<void> sendNudge(Nudge nudge) async {
    await _firestore
        .collection('social')
        .doc('nudges')
        .collection('items')
        .doc(nudge.id)
        .set(nudge.toJson());
  }

  /// Watch incoming nudges for the current user.
  Stream<List<Nudge>> watchIncomingNudges() {
    return _firestore
        .collection('social')
        .doc('nudges')
        .collection('items')
        .where('toUid', isEqualTo: _userId)
        .where('status', isEqualTo: NudgeStatus.pending.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Nudge.fromJson(doc.data())).toList());
  }

  /// Mark nudge as seen.
  Future<void> markNudgeSeen(String nudgeId) async {
    await _firestore
        .collection('social')
        .doc('nudges')
        .collection('items')
        .doc(nudgeId)
        .update({'status': NudgeStatus.seen.name});
  }
}
