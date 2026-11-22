import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'graph_changeset.dart';

/// Transport layer that exchanges [GraphChangeset]s between devices via a
/// Firestore log of numbered entries.
///
/// Every push takes the next number from a counter in the same transaction
/// that writes the entry, so numbers follow commit order: once entry `n` is
/// visible, every entry below it is too. A device's pull bookmark is the
/// highest number it has read, which is exact however old the clocks inside
/// a late-pushed entry are.
///
/// Each device publishes how far it has read and pushed. An entry is deleted
/// only once every device has read past it.
///
/// ```
/// users/{uid}/sync_log_v2/{auto-id}
///   seq: int            // position in the log, from sync_state/log
///   nodeId: String
///   changeset: Map<String, dynamic>
///   maxHlc: String
///   createdAt: Timestamp (server)
/// users/{uid}/sync_state/log
///   lastSeq: int
/// users/{uid}/sync_devices/{nodeId}
///   pulledSeq: int      // highest entry this device has read
///   pushedHlc: String   // this device's push bookmark
///   updatedAt: Timestamp (server)
/// ```
///
/// The log is per-user and typically has 1-3 devices, so filtering by
/// `nodeId` in Dart (rather than a compound Firestore query) avoids composite
/// index management.
class FirestoreSyncTransport {
  FirestoreSyncTransport({
    required FirebaseFirestore firestore,
    required String userId,
    int maxEntryBytes = 700000,
  }) : _firestore = firestore,
       _maxEntryBytes = maxEntryBytes,
       _user = firestore.collection('users').doc(userId);

  final FirebaseFirestore _firestore;
  final DocumentReference<Map<String, dynamic>> _user;

  /// Encoded size above which a push is split into several entries, kept
  /// well under Firestore's 1 MiB document limit.
  final int _maxEntryBytes;

  CollectionReference<Map<String, dynamic>> get _log =>
      _user.collection('sync_log_v2');
  DocumentReference<Map<String, dynamic>> get _counter =>
      _user.collection('sync_state').doc('log');
  CollectionReference<Map<String, dynamic>> get _devices =>
      _user.collection('sync_devices');

  /// Pushes a changeset as one or more numbered entries. Skips empty
  /// changesets.
  Future<void> pushChangeset({
    required GraphChangeset changeset,
    required String nodeId,
  }) async {
    if (changeset.isEmpty) return;

    for (final chunk in _chunks(changeset.toJson())) {
      await _firestore.runTransaction((tx) async {
        final counter = await tx.get(_counter);
        final seq = switch (counter.data()?['lastSeq']) {
          final int last => last + 1,
          _ => 1,
        };
        tx.set(_counter, {'lastSeq': seq});
        tx.set(_log.doc(), {
          'seq': seq,
          'nodeId': nodeId,
          'changeset': chunk,
          'maxHlc': GraphChangeset.fromJson(chunk).maxHlc,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  /// Splits a changeset's wire map into maps whose encoded rows fit within
  /// [_maxEntryBytes]. A single row larger than that goes alone.
  List<Map<String, List<Map<String, Object?>>>> _chunks(
    Map<String, List<Map<String, Object?>>> json,
  ) {
    final chunks = <Map<String, List<Map<String, Object?>>>>[];
    var current = <String, List<Map<String, Object?>>>{};
    var size = 0;
    for (final MapEntry(key: table, value: rows) in json.entries) {
      for (final row in rows) {
        final rowSize = utf8.encode(jsonEncode(row)).length;
        if (size > 0 && size + rowSize > _maxEntryBytes) {
          chunks.add(current);
          current = {};
          size = 0;
        }
        (current[table] ??= []).add(row);
        size += rowSize;
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  /// Pulls entries after [afterSeq].
  ///
  /// Returns the changesets other devices pushed, and the highest number
  /// read, counting this device's own entries so they don't hold the
  /// bookmark back.
  Future<({List<GraphChangeset> changesets, int lastSeq})> pullChangesets({
    required int afterSeq,
    required String localNodeId,
  }) async {
    final snapshot =
        await _log.where('seq', isGreaterThan: afterSeq).orderBy('seq').get();

    final changesets = <GraphChangeset>[];
    var lastSeq = afterSeq;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['seq'] case final int seq when seq > lastSeq) lastSeq = seq;
      if (data['nodeId'] == localNodeId) continue;
      if (data['changeset'] case final Map<String, dynamic> changeset) {
        changesets.add(GraphChangeset.fromJson(changeset));
      }
    }
    return (changesets: changesets, lastSeq: lastSeq);
  }

  /// Publishes how far this device has read the log and pushed its changes.
  Future<void> publishProgress({
    required String nodeId,
    required int pulledSeq,
    required String pushedHlc,
  }) async {
    await _devices.doc(nodeId).set({
      'pulledSeq': pulledSeq,
      'pushedHlc': pushedHlc,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The progress every device has reached: the lowest `pulledSeq` and the
  /// lowest `pushedHlc` across all devices that have published, and the
  /// node ids of those devices; or null if none has.
  ///
  /// Entries at or below `pulledSeq` have been read by every device.
  /// Every device's unpushed changes carry clocks above `pushedHlc`, so a
  /// tombstone older than it can't be outvoted by a stale row still to come.
  /// A device that hasn't published yet holds nothing back, so a device that
  /// sees a new one in `devices` must push its whole graph again.
  Future<({int pulledSeq, String pushedHlc, Set<String> devices})?>
  readHorizon() async {
    final snapshot = await _devices.get();
    int? pulledSeq;
    String? pushedHlc;
    final devices = <String>{};
    for (final doc in snapshot.docs) {
      devices.add(doc.id);
      final data = doc.data();
      final seq = switch (data['pulledSeq']) {
        final int s => s,
        _ => 0,
      };
      final hlc = switch (data['pushedHlc']) {
        final String h => h,
        _ => '',
      };
      if (pulledSeq == null || seq < pulledSeq) pulledSeq = seq;
      if (pushedHlc == null || hlc.compareTo(pushedHlc) < 0) pushedHlc = hlc;
    }
    if (pulledSeq == null || pushedHlc == null) return null;
    return (pulledSeq: pulledSeq, pushedHlc: pushedHlc, devices: devices);
  }

  /// Deletes entries numbered at or below [throughSeq]. Pass the
  /// `pulledSeq` from [readHorizon], so only entries every device has read
  /// are removed.
  Future<int> cleanup({required int throughSeq}) async {
    final snapshot =
        await _log.where('seq', isLessThanOrEqualTo: throughSeq).get();

    // Firestore allows at most 500 writes per batch.
    final docs = snapshot.docs;
    for (var start = 0; start < docs.length; start += 500) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(start).take(500)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return docs.length;
  }
}
