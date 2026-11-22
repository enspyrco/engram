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
/// Entries are never deleted: the log is the only copy of the graph outside
/// the devices, so a new or restored device replays it from the start. It can
/// shrink only once a snapshot holds what it would delete.
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
      if (data['nodeId'] != localNodeId) {
        // A platform may hand nested maps back with looser type arguments;
        // the JSON round trip gives fromJson the shape it reads. An entry
        // that can't be read stops the pull, so the bookmark never passes an
        // entry that wasn't merged.
        final raw = data['changeset'];
        if (raw is! Map) {
          throw FormatException('sync log entry ${doc.id} has no changeset');
        }
        // cast-ok: jsonDecode of an encoded Map is a Map<String, dynamic>.
        final json = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
        changesets.add(GraphChangeset.fromJson(json));
      }
      if (data['seq'] case final int seq when seq > lastSeq) lastSeq = seq;
    }
    return (changesets: changesets, lastSeq: lastSeq);
  }
}
