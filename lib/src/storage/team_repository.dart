import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catastrophe_event.dart';
import '../models/concept_cluster.dart';
import '../models/network_health.dart';
import '../models/repair_mission.dart';

/// Firestore operations for team network state: health snapshots,
/// catastrophe events, concept clusters, and repair missions.
///
/// Schema:
///   wikiGroups/{hash}/networkState/current     — aggregate health
///   wikiGroups/{hash}/events/{eventId}         — catastrophe history
///   wikiGroups/{hash}/clusters/{clusterId}     — cluster defs + guardian
///   wikiGroups/{hash}/missions/{missionId}     — repair missions
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
}
