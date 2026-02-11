import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catastrophe_event.dart';
import '../models/concept_cluster.dart';
import '../models/entropy_storm.dart';
import '../models/glory_entry.dart';
import '../models/network_health.dart';
import '../models/relay_challenge.dart';
import '../models/repair_mission.dart';
import '../models/team_goal.dart';

/// Firestore operations for team network state: health snapshots,
/// catastrophe events, concept clusters, and repair missions.
///
/// Schema:
///   wikiGroups/{hash}/networkState/current     — aggregate health
///   wikiGroups/{hash}/events/{eventId}         — catastrophe history
///   wikiGroups/{hash}/clusters/{clusterId}     — cluster defs + guardian
///   wikiGroups/{hash}/missions/{missionId}     — repair missions
///   wikiGroups/{hash}/goals/{goalId}           — team goals
///   wikiGroups/{hash}/glory/{uid}              — glory board entries
///   wikiGroups/{hash}/relays/{relayId}         — relay challenges
///   wikiGroups/{hash}/storms/{stormId}         — entropy storms
class TeamRepository {
  TeamRepository({
    required FirebaseFirestore firestore,
    required String wikiUrlHash,
  })  : _firestore = firestore,
        _wikiUrlHash = wikiUrlHash;

  final FirebaseFirestore _firestore;
  final String _wikiUrlHash;

  DocumentReference get _groupDoc =>
      _firestore.collection('wikiGroups').doc(_wikiUrlHash);

  // --- Network Health ---

  /// Persist the latest health snapshot.
  Future<void> writeNetworkHealth(NetworkHealth health) async {
    await _groupDoc
        .collection('networkState')
        .doc('current')
        .set(health.toJson());
  }

  /// Stream the current network health.
  Stream<NetworkHealth?> watchNetworkHealth() {
    return _groupDoc
        .collection('networkState')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return NetworkHealth.fromJson(doc.data()!);
    });
  }

  // --- Catastrophe Events ---

  /// Record a new catastrophe event.
  Future<void> writeCatastropheEvent(CatastropheEvent event) async {
    await _groupDoc.collection('events').doc(event.id).set(event.toJson());
  }

  /// Mark a catastrophe event as resolved.
  Future<void> resolveCatastropheEvent(String eventId, String timestamp) async {
    await _groupDoc
        .collection('events')
        .doc(eventId)
        .update({'resolvedAt': timestamp});
  }

  /// Stream unresolved catastrophe events.
  Stream<List<CatastropheEvent>> watchActiveEvents() {
    return _groupDoc
        .collection('events')
        .where('resolvedAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CatastropheEvent.fromJson(doc.data()))
            .toList());
  }

  /// Stream all catastrophe events (for history).
  Stream<List<CatastropheEvent>> watchAllEvents() {
    return _groupDoc.collection('events').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => CatastropheEvent.fromJson(doc.data()))
            .toList());
  }

  // --- Concept Clusters ---

  /// Write cluster definitions (typically after re-detection).
  Future<void> writeClusters(List<ConceptCluster> clusters) async {
    final batch = _firestore.batch();
    final collectionRef = _groupDoc.collection('clusters');

    // Delete old clusters
    final existing = await collectionRef.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    // Write new clusters
    for (var i = 0; i < clusters.length; i++) {
      batch.set(collectionRef.doc('cluster_$i'), clusters[i].toJson());
    }

    await batch.commit();
  }

  /// Assign a guardian to a cluster.
  Future<void> setClusterGuardian(
    String clusterDocId,
    String? guardianUid,
  ) async {
    await _groupDoc
        .collection('clusters')
        .doc(clusterDocId)
        .update({'guardianUid': guardianUid});
  }

  /// Stream current clusters.
  Stream<List<ConceptCluster>> watchClusters() {
    return _groupDoc.collection('clusters').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => ConceptCluster.fromJson(doc.data()))
            .toList());
  }

  // --- Repair Missions ---

  /// Create a new repair mission.
  Future<void> writeRepairMission(RepairMission mission) async {
    await _groupDoc
        .collection('missions')
        .doc(mission.id)
        .set(mission.toJson());
  }

  /// Update a repair mission (e.g., after reviewing a concept).
  Future<void> updateRepairMission(RepairMission mission) async {
    await _groupDoc
        .collection('missions')
        .doc(mission.id)
        .set(mission.toJson());
  }

  /// Stream active (uncompleted) repair missions.
  Stream<List<RepairMission>> watchActiveMissions() {
    return _groupDoc
        .collection('missions')
        .where('completedAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RepairMission.fromJson(doc.data()))
            .toList());
  }

  // --- Team Goals ---

  /// Create or update a team goal.
  Future<void> writeTeamGoal(TeamGoal goal) async {
    await _groupDoc.collection('goals').doc(goal.id).set(goal.toJson());
  }

  /// Stream active (uncompleted) goals.
  Stream<List<TeamGoal>> watchActiveGoals() {
    return _groupDoc
        .collection('goals')
        .where('completedAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamGoal.fromJson(doc.data()))
            .toList());
  }

  /// Update a goal's contribution map for a specific user.
  Future<void> updateGoalContribution(
    String goalId,
    String uid,
    double amount,
  ) async {
    await _groupDoc.collection('goals').doc(goalId).update({
      'contributions.$uid': FieldValue.increment(amount),
    });
  }

  /// Mark a goal as completed.
  Future<void> completeGoal(String goalId, String timestamp) async {
    await _groupDoc
        .collection('goals')
        .doc(goalId)
        .update({'completedAt': timestamp});
  }

  // --- Glory Board ---

  /// Write or update a glory entry for a user.
  Future<void> writeGloryEntry(GloryEntry entry) async {
    await _groupDoc
        .collection('glory')
        .doc(entry.uid)
        .set(entry.toJson());
  }

  /// Increment a specific point category for a user.
  Future<void> addGloryPoints(
    String uid, {
    int guardianPoints = 0,
    int missionPoints = 0,
    int goalPoints = 0,
    int relayPoints = 0,
    int stormPoints = 0,
  }) async {
    final updates = <String, dynamic>{};
    if (guardianPoints != 0) {
      updates['guardianPoints'] = FieldValue.increment(guardianPoints);
    }
    if (missionPoints != 0) {
      updates['missionPoints'] = FieldValue.increment(missionPoints);
    }
    if (goalPoints != 0) {
      updates['goalPoints'] = FieldValue.increment(goalPoints);
    }
    if (relayPoints != 0) {
      updates['relayPoints'] = FieldValue.increment(relayPoints);
    }
    if (stormPoints != 0) {
      updates['stormPoints'] = FieldValue.increment(stormPoints);
    }
    if (updates.isEmpty) return;

    await _groupDoc.collection('glory').doc(uid).set(updates, SetOptions(merge: true));
  }

  /// Stream the full glory board (all members, sorted client-side).
  Stream<List<GloryEntry>> watchGloryBoard() {
    return _groupDoc.collection('glory').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => GloryEntry.fromJson(doc.data()))
            .toList());
  }

  /// Stream a single user's glory entry.
  Stream<GloryEntry?> watchGloryEntry(String uid) {
    return _groupDoc
        .collection('glory')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GloryEntry.fromJson(doc.data()!);
    });
  }

  // --- Relay Challenges ---

  /// Create a new relay challenge.
  Future<void> writeRelay(RelayChallenge relay) async {
    await _groupDoc.collection('relays').doc(relay.id).set(relay.toJson());
  }

  /// Update a relay challenge (e.g., after claiming or completing a leg).
  Future<void> updateRelay(RelayChallenge relay) async {
    await _groupDoc.collection('relays').doc(relay.id).set(relay.toJson());
  }

  /// Stream active (uncompleted) relay challenges.
  Stream<List<RelayChallenge>> watchActiveRelays() {
    return _groupDoc
        .collection('relays')
        .where('completedAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RelayChallenge.fromJson(doc.data()))
            .toList());
  }

  // --- Entropy Storms ---

  /// Create a new entropy storm.
  Future<void> writeStorm(EntropyStorm storm) async {
    await _groupDoc.collection('storms').doc(storm.id).set(storm.toJson());
  }

  /// Update a storm (e.g., status change, participant opt-in/out).
  Future<void> updateStorm(EntropyStorm storm) async {
    await _groupDoc.collection('storms').doc(storm.id).set(storm.toJson());
  }

  /// Stream the current active or scheduled storm (limit 1, newest first).
  Stream<EntropyStorm?> watchActiveStorm() {
    return _groupDoc
        .collection('storms')
        .where('status', whereIn: ['scheduled', 'active'])
        .orderBy('scheduledStart')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return EntropyStorm.fromJson(snapshot.docs.first.data());
    });
  }
}
