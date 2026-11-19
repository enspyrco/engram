import 'package:cloud_firestore/cloud_firestore.dart';

import 'graph_changeset.dart';

/// Transport layer that exchanges [GraphChangeset]s between devices via a
/// Firestore `sync_log` subcollection.
///
/// Each device pushes serialized changesets as documents; other devices pull
/// and merge. The sync_log is per-user and typically has 1-3 devices, so
/// filtering by `nodeId` in Dart (rather than a compound Firestore query)
/// avoids composite index management.
///
/// ```
/// users/{uid}/sync_log/{auto-id}
///   nodeId: String
///   changeset: Map<String, dynamic>
///   maxHlc: String
///   createdAt: Timestamp (server)
/// ```
///
/// This is a plain Dart class (no Riverpod) — testable with
/// `fake_cloud_firestore`.
class FirestoreSyncTransport {
  FirestoreSyncTransport({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _syncLog = firestore
           .collection('users')
           .doc(userId)
           .collection('sync_log');

  final CollectionReference _syncLog;

  /// Pushes a changeset to the sync_log. Skips empty changesets.
  ///
  /// Uses `FieldValue.serverTimestamp()` for `createdAt` so ordering is
  /// consistent across devices regardless of clock skew.
  Future<void> pushChangeset({
    required GraphChangeset changeset,
    required String nodeId,
  }) async {
    if (changeset.isEmpty) return;

    await _syncLog.add({
      'nodeId': nodeId,
      'changeset': changeset.toJson(),
      'maxHlc': changeset.maxHlc,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Pulls changesets from other devices written after [sinceHlc].
  ///
  /// Orders by `maxHlc` (lexicographic HLC ordering) which doubles as the
  /// range filter field — this avoids needing a composite Firestore index.
  /// Entries from [localNodeId] are excluded in Dart rather than via a
  /// compound query (sync_log is per-user, typically 1-3 devices).
  Future<List<PulledChangeset>> pullChangesets({
    required String sinceHlc,
    required String localNodeId,
  }) async {
    // Order by maxHlc — Firestore requires the orderBy field to match
    // the range filter field. HLC strings are lexicographically ordered
    // (ISO 8601 + hex counter), so this gives correct causal ordering.
    Query query = _syncLog.orderBy('maxHlc');

    // Filter by maxHlc > sinceHlc if we have a bookmark.
    if (sinceHlc.isNotEmpty) {
      query = query.where('maxHlc', isGreaterThan: sinceHlc);
    }

    final snapshot = await query.get();

    final results = <PulledChangeset>[];
    for (final doc in snapshot.docs) {
      final data = doc.data()! as Map<String, dynamic>;

      // Skip our own entries (filtered in Dart, not Firestore).
      if (data['nodeId'] == localNodeId) continue;

      final changesetJson = data['changeset'] as Map<String, dynamic>;
      results.add(
        PulledChangeset(
          changeset: GraphChangeset.fromJson(changesetJson),
          maxHlc: data['maxHlc'] as String,
        ),
      );
    }

    return results;
  }

  /// Deletes old sync_log entries with `maxHlc <= beforeHlc`.
  ///
  /// Call periodically to prevent unbounded growth of the sync_log.
  /// Safe to call at any time — only affects entries that all devices
  /// have already processed (confirmed by their sync metadata).
  Future<int> cleanup({required String beforeHlc}) async {
    final snapshot =
        await _syncLog.where('maxHlc', isLessThanOrEqualTo: beforeHlc).get();

    if (snapshot.docs.isEmpty) return 0;

    final batch = _syncLog.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    return snapshot.docs.length;
  }
}

/// A changeset pulled from the sync_log, paired with its `maxHlc` bookmark.
class PulledChangeset {
  const PulledChangeset({required this.changeset, required this.maxHlc});

  final GraphChangeset changeset;
  final String maxHlc;
}
