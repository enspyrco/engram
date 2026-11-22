import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import '../../crdt/graph_changeset.dart';
import '../../crdt/hlc_manager.dart';
import '../../models/concept.dart';
import '../../models/knowledge_graph.dart';
import '../../models/quiz_item.dart';
import '../../models/relationship.dart';
import '../../models/topic.dart';
import '../graph_repository.dart';
import 'drift_mappers.dart';
import 'engram_database.dart';

/// [GraphRepository] backed by a local Drift/SQLite database.
///
/// Primary storage for unauthenticated/offline users. Provides reactive
/// [watch] via Drift's table-update streams and efficient single-row
/// updates for quiz reviews.
///
/// All write operations run inside transactions so [watch] listeners see
/// atomic updates. Each write touches only the rows it names and stamps
/// them with one clock reading, so a row's clock means "when this row last
/// changed". Deletion is a tombstone (`isDeleted = true`) on ids a write
/// names explicitly, kept for CRDT changeset propagation.
///
/// When an [HlcManager] is provided, every write is stamped with a
/// Hybrid Logical Clock timestamp for CRDT sync. Rows with
/// `isDeleted = true` are excluded from [load] results but preserved
/// in the database for changeset propagation.
class DriftGraphRepository extends GraphRepository {
  DriftGraphRepository({
    required EngramDatabase db,
    HlcManager? hlcManager,
    DateTime Function()? clock,
  }) : _db = db,
       _hlcManager = hlcManager,
       _clock = clock ?? _defaultClock;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final EngramDatabase _db;
  final HlcManager? _hlcManager;
  final DateTime Function() _clock;

  /// Returns the current HLC string for stamping writes, or empty string
  /// if no HlcManager is configured (backward compatible).
  String _stampHlc() => _hlcManager?.now().toString() ?? '';

  // -------------------------------------------------------------------------
  // load
  // -------------------------------------------------------------------------

  @override
  Future<KnowledgeGraph> load() async {
    // Query all tables in parallel, filtering out tombstoned rows.
    final results = await Future.wait([
      (_db.select(_db.driftConcepts)
        ..where((t) => t.isDeleted.equals(false))).get(), // 0
      (_db.select(_db.driftRelationships)
        ..where((t) => t.isDeleted.equals(false))).get(), // 1
      (_db.select(_db.driftQuizItems)
        ..where((t) => t.isDeleted.equals(false))).get(), // 2
      (_db.select(_db.driftDocuments)
        ..where((t) => t.isDeleted.equals(false))).get(), // 3
      (_db.select(_db.driftTopics)
        ..where((t) => t.isDeleted.equals(false))).get(), // 4
      (_db.select(_db.driftTopicDocuments)
        ..where((t) => t.isDeleted.equals(false))).get(), // 5
    ]);

    final conceptRows = results[0] as List<DriftConcept>;
    final relationshipRows = results[1] as List<DriftRelationship>;
    final quizItemRows = results[2] as List<DriftQuizItem>;
    final documentRows = results[3] as List<DriftDocument>;
    final topicRows = results[4] as List<DriftTopic>;
    final topicDocRows = results[5] as List<DriftTopicDocument>;

    // Group topic-document join rows by topicId for efficient reconstruction.
    final topicDocMap = <String, Set<String>>{};
    for (final row in topicDocRows) {
      (topicDocMap[row.topicId] ??= {}).add(row.documentId);
    }

    return KnowledgeGraph(
      concepts: conceptRows.map((r) => r.toDomain()).toList(),
      relationships: relationshipRows.map((r) => r.toDomain()).toList(),
      quizItems: quizItemRows.map((r) => r.toDomain()).toList(),
      documentMetadata: documentRows.map((r) => r.toDomain()).toList(),
      topics:
          topicRows
              .map(
                (r) => r.toDomain(documentIds: topicDocMap[r.id] ?? const {}),
              )
              .toList(),
    );
  }

  // -------------------------------------------------------------------------
  // seedEmpty — whole-graph write into a store with no rows
  // -------------------------------------------------------------------------

  @override
  Future<bool> seedEmpty(KnowledgeGraph graph) {
    return _db.transaction(() async {
      if (await _hasAnyRow()) return false;
      // The lowest clock, not the current one: a seed is a baseline copied
      // from elsewhere, and any real write on any device must beat it.
      final hlc = switch (_hlcManager) {
        final manager? => Hlc.zero(manager.nodeId).toString(),
        null => '',
      };
      await _db.batch((batch) {
        batch.insertAll(
          _db.driftConcepts,
          graph.concepts.map((c) => c.toCompanion(hlc: hlc)).toList(),
        );
        batch.insertAll(
          _db.driftRelationships,
          graph.relationships.map((r) => r.toCompanion(hlc: hlc)).toList(),
        );
        batch.insertAll(
          _db.driftQuizItems,
          graph.quizItems.map((q) => q.toCompanion(hlc: hlc)).toList(),
        );
        batch.insertAll(
          _db.driftDocuments,
          graph.documentMetadata.map((d) => d.toCompanion(hlc: hlc)).toList(),
        );
        batch.insertAll(
          _db.driftTopics,
          graph.topics.map((t) => t.toCompanion(hlc: hlc)).toList(),
        );
        batch.insertAll(_db.driftTopicDocuments, [
          for (final topic in graph.topics)
            for (final docId in topic.documentIds)
              DriftTopicDocumentsCompanion.insert(
                topicId: topic.id,
                documentId: docId,
                hlc: Value(hlc),
              ),
        ]);
      });
      return true;
    });
  }

  /// Whether any table has a row, tombstones included.
  Future<bool> _hasAnyRow() async {
    final tables = <TableInfo<Table, Object?>>[
      _db.driftConcepts,
      _db.driftRelationships,
      _db.driftQuizItems,
      _db.driftDocuments,
      _db.driftTopics,
      _db.driftTopicDocuments,
    ];
    for (final table in tables) {
      final row =
          await (_db.selectOnly(table)
                ..addColumns([const CustomExpression<int>('1')])
                ..limit(1))
              .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // applyExtraction — one document's rows, and the ids it drops
  // -------------------------------------------------------------------------

  @override
  Future<void> applyExtraction(ExtractionPatch patch) async {
    await _db.transaction(() async {
      final hlc = _stampHlc();

      // insertOrReplace also revives a tombstoned row the extraction
      // brings back, because it resets isDeleted to its default (false).
      await _db.batch((batch) {
        batch.insertAll(
          _db.driftConcepts,
          patch.concepts.map((c) => c.toCompanion(hlc: hlc)).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.driftRelationships,
          patch.relationships.map((r) => r.toCompanion(hlc: hlc)).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.driftQuizItems,
          patch.quizItems.map((q) => q.toCompanion(hlc: hlc)).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insert(
          _db.driftDocuments,
          patch.document.toCompanion(hlc: hlc),
          mode: InsertMode.insertOrReplace,
        );
      });

      await (_db.update(_db.driftConcepts)..where(
        (t) => t.isDeleted.equals(false) & t.id.isIn(patch.removedConceptIds),
      )).write(
        DriftConceptsCompanion(isDeleted: const Value(true), hlc: Value(hlc)),
      );
      await (_db.update(_db.driftRelationships)..where(
        (t) =>
            t.isDeleted.equals(false) & t.id.isIn(patch.removedRelationshipIds),
      )).write(
        DriftRelationshipsCompanion(
          isDeleted: const Value(true),
          hlc: Value(hlc),
        ),
      );
      await (_db.update(_db.driftQuizItems)..where(
        (t) => t.isDeleted.equals(false) & t.id.isIn(patch.removedQuizItemIds),
      )).write(
        DriftQuizItemsCompanion(isDeleted: const Value(true), hlc: Value(hlc)),
      );
    });
  }

  // -------------------------------------------------------------------------
  // topics and document metadata
  // -------------------------------------------------------------------------

  @override
  Future<void> upsertTopic(Topic topic, {Topic? previous}) async {
    final before = previous?.documentIds.toSet() ?? const <String>{};
    final after = topic.documentIds.toSet();
    final added = after.difference(before);
    final removed = before.difference(after);

    await _db.transaction(() async {
      final hlc = _stampHlc();
      if (previous == null) {
        await _db
            .into(_db.driftTopics)
            .insert(
              topic.toCompanion(hlc: hlc),
              mode: InsertMode.insertOrReplace,
            );
      } else if (topic.name != previous.name ||
          topic.description != previous.description) {
        // Only the fields the caller changed, so a stale copy can't put back
        // a rename or ingest time made elsewhere.
        await (_db.update(_db.driftTopics)
          ..where((t) => t.id.equals(topic.id))).write(
          DriftTopicsCompanion(
            name:
                topic.name != previous.name
                    ? Value(topic.name)
                    : const Value.absent(),
            description:
                topic.description != previous.description
                    ? Value(topic.description)
                    : const Value.absent(),
            hlc: Value(hlc),
          ),
        );
      }
      await _db.batch((batch) {
        batch.insertAll(_db.driftTopicDocuments, [
          for (final docId in added)
            DriftTopicDocumentsCompanion.insert(
              topicId: topic.id,
              documentId: docId,
              hlc: Value(hlc),
            ),
        ], mode: InsertMode.insertOrReplace);
      });
      await (_db.update(_db.driftTopicDocuments)..where(
        (t) => t.topicId.equals(topic.id) & t.documentId.isIn(removed),
      )).write(
        DriftTopicDocumentsCompanion(
          isDeleted: const Value(true),
          hlc: Value(hlc),
        ),
      );
    });
  }

  @override
  Future<void> markTopicIngested(String topicId, DateTime at) async {
    await (_db.update(_db.driftTopics)
      ..where((t) => t.id.equals(topicId))).write(
      DriftTopicsCompanion(
        lastIngestedAt: Value(at.toIso8601String()),
        hlc: Value(_stampHlc()),
      ),
    );
  }

  @override
  Future<void> setDocumentCollection(
    String documentId, {
    required String collectionId,
    required String collectionName,
  }) async {
    await (_db.update(_db.driftDocuments)
      ..where((t) => t.documentId.equals(documentId))).write(
      DriftDocumentsCompanion(
        collectionId: Value(collectionId),
        collectionName: Value(collectionName),
        hlc: Value(_stampHlc()),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // purgeTombstones — physical deletion for sync cleanup
  // -------------------------------------------------------------------------

  /// Physically removes tombstoned rows with `hlc < [before]`.
  ///
  /// Called by the sync layer after confirming all replicas have received
  /// the tombstones. This prevents unbounded tombstone growth. Safe to call
  /// at any time — only affects rows that are already soft-deleted and
  /// whose HLC timestamp is strictly less than the threshold.
  ///
  /// Returns the total number of rows purged across all tables.
  Future<int> purgeTombstones({required String before}) async {
    var count = 0;
    await _db.transaction(() async {
      count +=
          await (_db.delete(_db.driftTopicDocuments)..where(
            (t) => t.isDeleted.equals(true) & t.hlc.isSmallerThanValue(before),
          )).go();
      count +=
          await (_db.delete(_db.driftTopics)..where(
            (t) => t.isDeleted.equals(true) & t.hlc.isSmallerThanValue(before),
          )).go();
      count +=
          await (_db.delete(_db.driftDocuments)..where(
            (t) => t.isDeleted.equals(true) & t.hlc.isSmallerThanValue(before),
          )).go();
      count +=
          await (_db.delete(_db.driftQuizItems)..where(
            (t) => t.isDeleted.equals(true) & t.hlc.isSmallerThanValue(before),
          )).go();
      count +=
          await (_db.delete(_db.driftRelationships)..where(
            (t) => t.isDeleted.equals(true) & t.hlc.isSmallerThanValue(before),
          )).go();
      count +=
          await (_db.delete(_db.driftConcepts)..where(
            (t) => t.isDeleted.equals(true) & t.hlc.isSmallerThanValue(before),
          )).go();
    });
    return count;
  }

  // -------------------------------------------------------------------------
  // updateQuizItem — O(1) single-row write
  // -------------------------------------------------------------------------

  @override
  Future<void> updateQuizItem(QuizItem item) async {
    await _db
        .into(_db.driftQuizItems)
        .insertOnConflictUpdate(item.toCompanion(hlc: _stampHlc()));
  }

  // -------------------------------------------------------------------------
  // saveSplitData — additive only (no deletes)
  // -------------------------------------------------------------------------

  @override
  Future<void> saveSplitData({
    required List<Concept> concepts,
    required List<Relationship> relationships,
    required List<QuizItem> quizItems,
  }) async {
    final hlc = _stampHlc();
    await _db.batch((batch) {
      batch.insertAll(
        _db.driftConcepts,
        concepts.map((c) => c.toCompanion(hlc: hlc)).toList(),
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _db.driftRelationships,
        relationships.map((r) => r.toCompanion(hlc: hlc)).toList(),
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _db.driftQuizItems,
        quizItems.map((q) => q.toCompanion(hlc: hlc)).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  // -------------------------------------------------------------------------
  // watch — reactive stream
  // -------------------------------------------------------------------------

  /// Emits the full [KnowledgeGraph] on initial subscription and whenever
  /// any table changes.
  ///
  /// Uses Drift's [tableUpdates] to listen for changes across all 6 tables,
  /// then re-loads the entire graph. This is simple and correct — SQLite
  /// reads are fast enough that a full reload on each change is fine for
  /// the expected data sizes (hundreds to low thousands of rows).
  @override
  Stream<KnowledgeGraph> watch() async* {
    // Emit current state immediately.
    yield await load();

    // Then emit on every subsequent table change.
    yield* _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.driftConcepts,
            _db.driftRelationships,
            _db.driftQuizItems,
            _db.driftDocuments,
            _db.driftTopics,
            _db.driftTopicDocuments,
          ]),
        )
        .asyncMap((_) => load());
  }

  // -------------------------------------------------------------------------
  // getChangeset — extract modified rows since an HLC
  // -------------------------------------------------------------------------

  /// Returns all rows modified after [modifiedAfter] across all tables.
  ///
  /// Includes tombstoned rows (`isDeleted = true`) so that deletions
  /// propagate to other replicas. Pass an empty string to get the full
  /// state (every row in the database).
  ///
  /// Works because HLC strings are lexicographically ordered (ISO 8601
  /// date prefix + zero-padded hex counter), so `WHERE hlc > ?` is a
  /// simple string comparison in SQLite, accelerated by the `idx_*_hlc`
  /// indexes added in schema v3.
  Future<GraphChangeset> getChangeset({required String modifiedAfter}) async {
    final results = await Future.wait([
      (_db.select(_db.driftConcepts)
        ..where((t) => t.hlc.isBiggerThanValue(modifiedAfter))).get(),
      (_db.select(_db.driftRelationships)
        ..where((t) => t.hlc.isBiggerThanValue(modifiedAfter))).get(),
      (_db.select(_db.driftQuizItems)
        ..where((t) => t.hlc.isBiggerThanValue(modifiedAfter))).get(),
      (_db.select(_db.driftDocuments)
        ..where((t) => t.hlc.isBiggerThanValue(modifiedAfter))).get(),
      (_db.select(_db.driftTopics)
        ..where((t) => t.hlc.isBiggerThanValue(modifiedAfter))).get(),
      (_db.select(_db.driftTopicDocuments)
        ..where((t) => t.hlc.isBiggerThanValue(modifiedAfter))).get(),
    ]);

    return GraphChangeset(
      concepts: results[0] as List<DriftConcept>,
      relationships: results[1] as List<DriftRelationship>,
      quizItems: results[2] as List<DriftQuizItem>,
      documents: results[3] as List<DriftDocument>,
      topics: results[4] as List<DriftTopic>,
      topicDocuments: results[5] as List<DriftTopicDocument>,
    );
  }

  // -------------------------------------------------------------------------
  // mergeChangeset — apply incoming rows using LWW per HLC
  // -------------------------------------------------------------------------

  /// Merges an incoming changeset using last-write-wins (LWW) per HLC.
  ///
  /// For each table in the changeset:
  /// 1. Filters out same-node rows (echoed back via relay) and advances
  ///    the local clock for foreign rows (causal ordering).
  /// 2. Batch-SELECTs existing rows by primary key (`WHERE id IN (...)`).
  /// 3. Compares HLCs in Dart — rows with a newer HLC (or no existing
  ///    row) are winners.
  /// 4. Batch-INSERTs winners via `InsertMode.insertOrReplace`.
  ///
  /// Incoming HLCs are **preserved** (not re-stamped) — this is what makes
  /// merge idempotent. The entire operation runs in a transaction so
  /// [watch] listeners see a single atomic update.
  ///
  /// Returns the number of rows actually written (newer or new rows).
  Future<int> mergeChangeset(GraphChangeset changeset) async {
    if (changeset.isEmpty) return 0;
    final hlcManager = _hlcManager;
    if (hlcManager == null) {
      throw StateError('mergeChangeset requires an HlcManager');
    }

    var written = 0;

    await _db.transaction(() async {
      written += await _batchMerge<DriftConcept>(
        incoming: changeset.concepts,
        keyOf: (c) => c.id,
        hlcOf: (c) => c.hlc,
        companionOf: (c) => c.toInsertCompanion(),
        selectByKeys:
            (keys) =>
                (_db.select(_db.driftConcepts)
                  ..where((t) => t.id.isIn(keys))).get(),
        table: _db.driftConcepts,
        hlcManager: hlcManager,
      );
      written += await _batchMerge<DriftRelationship>(
        incoming: changeset.relationships,
        keyOf: (r) => r.id,
        hlcOf: (r) => r.hlc,
        companionOf: (r) => r.toInsertCompanion(),
        selectByKeys:
            (keys) =>
                (_db.select(_db.driftRelationships)
                  ..where((t) => t.id.isIn(keys))).get(),
        table: _db.driftRelationships,
        hlcManager: hlcManager,
      );
      written += await _batchMerge<DriftQuizItem>(
        incoming: changeset.quizItems,
        keyOf: (q) => q.id,
        hlcOf: (q) => q.hlc,
        companionOf: (q) => q.toInsertCompanion(),
        selectByKeys:
            (keys) =>
                (_db.select(_db.driftQuizItems)
                  ..where((t) => t.id.isIn(keys))).get(),
        table: _db.driftQuizItems,
        hlcManager: hlcManager,
      );
      written += await _batchMerge<DriftDocument>(
        incoming: changeset.documents,
        keyOf: (d) => d.documentId,
        hlcOf: (d) => d.hlc,
        companionOf: (d) => d.toInsertCompanion(),
        selectByKeys:
            (keys) =>
                (_db.select(_db.driftDocuments)
                  ..where((t) => t.documentId.isIn(keys))).get(),
        table: _db.driftDocuments,
        hlcManager: hlcManager,
      );
      written += await _batchMerge<DriftTopic>(
        incoming: changeset.topics,
        keyOf: (t) => t.id,
        hlcOf: (t) => t.hlc,
        companionOf: (t) => t.toInsertCompanion(),
        selectByKeys:
            (keys) =>
                (_db.select(_db.driftTopics)
                  ..where((t) => t.id.isIn(keys))).get(),
        table: _db.driftTopics,
        hlcManager: hlcManager,
      );
      written += await _batchMerge<DriftTopicDocument>(
        incoming: changeset.topicDocuments,
        keyOf: (td) => '${td.topicId}|${td.documentId}',
        hlcOf: (td) => td.hlc,
        companionOf: (td) => td.toInsertCompanion(),
        selectByKeys: (keys) async {
          // Composite PK — fetch by topicId set, then filter in Dart.
          final topicIds =
              changeset.topicDocuments.map((td) => td.topicId).toSet();
          final rows =
              await (_db.select(_db.driftTopicDocuments)
                ..where((t) => t.topicId.isIn(topicIds))).get();
          return rows
              .where((r) => keys.contains('${r.topicId}|${r.documentId}'))
              .toList();
        },
        table: _db.driftTopicDocuments,
        hlcManager: hlcManager,
      );
    });

    return written;
  }

  /// Batch-merges a list of incoming rows against existing rows in [table].
  ///
  /// Uses a single `SELECT ... WHERE key IN (...)` per table instead of
  /// per-row lookups, reducing N+1 queries to 1 SELECT + 1 batch INSERT.
  ///
  /// Note: SQLite's default `SQLITE_MAX_VARIABLE_NUMBER` is 999 (32766 in
  /// newer builds). At the expected scale (hundreds of rows per sync) this
  /// is not a concern. For very large changesets, chunk the key set.
  Future<int> _batchMerge<T>({
    required List<T> incoming,
    required String Function(T) keyOf,
    required String Function(T) hlcOf,
    required Insertable<dynamic> Function(T) companionOf,
    required Future<List<T>> Function(Set<String> keys) selectByKeys,
    required TableInfo<Table, dynamic> table,
    required HlcManager hlcManager,
  }) async {
    if (incoming.isEmpty) return 0;

    // 1. Filter out same-node rows and advance HLC for foreign rows.
    final foreign = <T>[];
    for (final row in incoming) {
      final hlc = hlcOf(row);
      if (_isSameNode(hlc, hlcManager)) continue;
      _receiveHlc(hlc, hlcManager);
      foreign.add(row);
    }
    if (foreign.isEmpty) return 0;

    // 2. Batch SELECT existing rows by primary key.
    final keys = foreign.map(keyOf).toSet();
    final existing = await selectByKeys(keys);
    final existingHlcByKey = {for (final e in existing) keyOf(e): hlcOf(e)};

    // 3. Determine winners — new rows or rows with a newer HLC.
    final winners = <T>[];
    for (final row in foreign) {
      final existingHlc = existingHlcByKey[keyOf(row)];
      if (existingHlc == null || hlcOf(row).compareTo(existingHlc) > 0) {
        winners.add(row);
      }
    }
    if (winners.isEmpty) return 0;

    // 4. Batch INSERT winners.
    await _db.batch((batch) {
      for (final winner in winners) {
        batch.insert(
          table,
          companionOf(winner),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    return winners.length;
  }

  /// Guards against merging our own HLCs back (would cause
  /// `DuplicateNodeException` in `Hlc.merge()`).
  ///
  /// Uses `Hlc.parse()` for exact node ID extraction rather than
  /// `endsWith()`, which could false-match if node IDs share a suffix.
  bool _isSameNode(String hlcString, HlcManager hlcManager) {
    if (hlcString.isEmpty) return false;
    try {
      return Hlc.parse(hlcString).nodeId == hlcManager.nodeId;
    } on Object {
      // Malformed HLC — treat as foreign node (safe fallback).
      return false;
    }
  }

  /// Advances the local HLC by receiving a remote HLC string.
  void _receiveHlc(String hlcString, HlcManager hlcManager) {
    if (hlcString.isEmpty) return;
    hlcManager.receive(Hlc.parse(hlcString));
  }

  // -------------------------------------------------------------------------
  // Sync metadata CRUD — per-peer HLC bookkeeping
  // -------------------------------------------------------------------------

  /// Returns the last HLC we synced with [peerId], or `null` if we've never
  /// synced with this peer.
  Future<String?> getLastSyncedHlc(String peerId) async {
    final row =
        await (_db.select(_db.driftSyncMetadata)
          ..where((t) => t.peerId.equals(peerId))).getSingleOrNull();
    return row?.lastSyncedHlc;
  }

  /// Upserts the last HLC synced with [peerId].
  ///
  /// Uses `insertOnConflictUpdate` so the first call creates the row and
  /// subsequent calls update it — no need for separate insert/update paths.
  Future<void> updateLastSyncedHlc(String peerId, String hlc) async {
    await _db
        .into(_db.driftSyncMetadata)
        .insertOnConflictUpdate(
          DriftSyncMetadataCompanion.insert(
            peerId: peerId,
            lastSyncedHlc: hlc,
            updatedAt: _clock().toIso8601String(),
          ),
        );
  }

  /// Returns the sync-log position stored for [peerId], or 0 if none.
  ///
  /// The bookmark column is text, so the number is stored in decimal.
  Future<int> getSyncedSeq(String peerId) async =>
      int.tryParse(await getLastSyncedHlc(peerId) ?? '') ?? 0;

  /// Stores the sync-log position reached with [peerId].
  Future<void> updateSyncedSeq(String peerId, int seq) =>
      updateLastSyncedHlc(peerId, '$seq');

  // -------------------------------------------------------------------------
  // getLastModified — highest HLC across all tables
  // -------------------------------------------------------------------------

  /// Returns the highest HLC across all tables, or empty string if the
  /// database is empty.
  ///
  /// Useful for "sync since last known state" bookkeeping — pass the
  /// result to [getChangeset] on the remote peer.
  Future<String> getLastModified() async {
    final results = await Future.wait([
      _maxHlc('drift_concepts'),
      _maxHlc('drift_relationships'),
      _maxHlc('drift_quiz_items'),
      _maxHlc('drift_documents'),
      _maxHlc('drift_topics'),
      _maxHlc('drift_topic_documents'),
    ]);

    return results.fold<String>('', (best, hlc) {
      if (hlc.isEmpty) return best;
      if (best.isEmpty) return hlc;
      return hlc.compareTo(best) > 0 ? hlc : best;
    });
  }

  /// Returns `MAX(hlc)` for a single table, or empty string if the table
  /// is empty. Uses a raw query since Drift's `max()` aggregate isn't
  /// available on non-query builders.
  Future<String> _maxHlc(String tableName) async {
    final result =
        await _db
            .customSelect('SELECT MAX(hlc) AS max_hlc FROM $tableName')
            .getSingle();
    return (result.data['max_hlc'] as String?) ?? '';
  }
}
