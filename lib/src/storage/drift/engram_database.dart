import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../models/relationship.dart';
import 'type_converters.dart';

part 'engram_database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

/// Stores [Concept] entities.
///
/// Maps 1:1 to the domain model. `tags` is stored as JSON TEXT since it's
/// never queried independently. `embedding` is reserved for future concept
/// embedding support (#39). `hlc` is the Hybrid Logical Clock timestamp
/// for CRDT sync (#41). `isDeleted` is a tombstone flag — deleted rows are
/// hidden from [load] but preserved for changeset propagation.
@TableIndex(name: 'idx_concepts_source_document', columns: {#sourceDocumentId})
@TableIndex(name: 'idx_drift_concepts_hlc', columns: {#hlc})
class DriftConcepts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get sourceDocumentId => text()();
  TextColumn get tags => text().map(const IListStringConverter())();
  TextColumn get parentConceptId => text().nullable()();
  BlobColumn get embedding => blob().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores [Relationship] entities.
///
/// `type` is stored as the enum name string via [RelationshipTypeConverter].
/// Unlike the domain model where [Relationship.type] is nullable (to
/// represent legacy data without an explicit type), this column is
/// non-nullable. This matches [Relationship.toJson], which always stores
/// [Relationship.resolvedType] — so the DB receives a resolved value even
/// for legacy relationships (inferred from the label via
/// [RelationshipType.inferFromLabel]).
@TableIndex(name: 'idx_relationships_from', columns: {#fromConceptId})
@TableIndex(name: 'idx_relationships_to', columns: {#toConceptId})
@TableIndex(name: 'idx_drift_relationships_hlc', columns: {#hlc})
class DriftRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get fromConceptId => text()();
  TextColumn get toConceptId => text()();
  TextColumn get label => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text().map(const RelationshipTypeConverter())();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores [QuizItem] entities with full FSRS scheduling state.
///
/// All FSRS fields (`difficulty`, `stability`, `fsrsState`, `lapses`) are
/// nullable to support the auto-migration path from legacy SM-2 cards,
/// though after FSRS Phase 3 all cards should have these fields populated.
@TableIndex(name: 'idx_quiz_items_concept', columns: {#conceptId})
@TableIndex(name: 'idx_quiz_items_next_review', columns: {#nextReview})
@TableIndex(name: 'idx_drift_quiz_items_hlc', columns: {#hlc})
class DriftQuizItems extends Table {
  TextColumn get id => text()();
  TextColumn get conceptId => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  IntColumn get interval => integer()();
  TextColumn get nextReview => text()();
  TextColumn get lastReview => text().nullable()();
  RealColumn get difficulty => real().nullable()();
  RealColumn get stability => real().nullable()();
  IntColumn get fsrsState => integer().nullable()();
  IntColumn get lapses => integer().nullable()();
  RealColumn get predictedDifficulty => real().nullable()();
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores [DocumentMetadata] for ingested Outline wiki documents.
///
/// `ingestedText` can be large (up to 100K chars) but SQLite handles
/// TEXT columns of any size without the 1MB Firestore document limit.
@TableIndex(name: 'idx_drift_documents_hlc', columns: {#hlc})
class DriftDocuments extends Table {
  TextColumn get documentId => text()();
  TextColumn get title => text()();
  TextColumn get updatedAt => text()();
  TextColumn get ingestedAt => text()();
  TextColumn get collectionId => text().nullable()();
  TextColumn get collectionName => text().nullable()();
  TextColumn get ingestedText => text().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {documentId};
}

/// Stores [Topic] entities (user-defined document groupings).
///
/// The topic's `documentIds` set is normalized into [DriftTopicDocuments]
/// rather than stored as JSON, since we need to query the relationship
/// from both directions (topic → documents, document → topics).
@TableIndex(name: 'idx_drift_topics_hlc', columns: {#hlc})
class DriftTopics extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get lastIngestedAt => text().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Join table linking [Topic]s to their documents.
///
/// Composite primary key (topicId, documentId) ensures uniqueness.
/// Each row carries its own HLC for CRDT sync — the relationship
/// itself is an entity that can be created/deleted independently.
@TableIndex(name: 'idx_drift_topic_documents_hlc', columns: {#hlc})
class DriftTopicDocuments extends Table {
  TextColumn get topicId => text()();
  TextColumn get documentId => text()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {topicId, documentId};
}

/// Stores per-peer sync metadata for the CRDT transport layer.
///
/// Each row tracks the last HLC we synced with a given peer, so
/// subsequent syncs only exchange the delta. Populated by the future
/// transport layer — the table is created now so the schema is ready.
class DriftSyncMetadata extends Table {
  TextColumn get peerId => text()();
  TextColumn get lastSyncedHlc => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {peerId};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// The local-first SQLite database for Engram.
///
/// Contains all knowledge graph data: concepts, relationships, quiz items,
/// document metadata, and topics. Designed to be the primary storage with
/// Firestore as a sync peer (see `docs/LOCAL_FIRST.md`).
///
/// Every table includes an `hlc` column for Hybrid Logical Clock timestamps,
/// which will be used by the CRDT sync layer in Phase 3 (#41).
@DriftDatabase(
  tables: [
    DriftConcepts,
    DriftRelationships,
    DriftQuizItems,
    DriftDocuments,
    DriftTopics,
    DriftTopicDocuments,
    DriftSyncMetadata,
  ],
)
class EngramDatabase extends _$EngramDatabase {
  EngramDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  /// Named constructor for tests — accepts an in-memory executor.
  EngramDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 → v2: Add is_deleted column with default false to all 6 tables.
        for (final table in [
          'drift_concepts',
          'drift_relationships',
          'drift_quiz_items',
          'drift_documents',
          'drift_topics',
          'drift_topic_documents',
        ]) {
          await m.database.customStatement(
            'ALTER TABLE $table ADD COLUMN is_deleted INTEGER '
            'NOT NULL DEFAULT 0',
          );
        }
      }
      if (from < 3) {
        // v2 → v3: Add HLC indexes for efficient changeset queries
        // (`WHERE hlc > ?`) and create sync metadata table.
        for (final table in [
          'drift_concepts',
          'drift_relationships',
          'drift_quiz_items',
          'drift_documents',
          'drift_topics',
          'drift_topic_documents',
        ]) {
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_${table}_hlc '
            'ON $table (hlc)',
          );
        }
        await m.database.customStatement(
          'CREATE TABLE IF NOT EXISTS drift_sync_metadata ('
          'peer_id TEXT NOT NULL PRIMARY KEY, '
          'last_synced_hlc TEXT NOT NULL, '
          'updated_at TEXT NOT NULL'
          ')',
        );
      }
    },
  );

  /// Opens the default on-disk database using drift_flutter.
  ///
  /// The [web] options are required when compiling to the web: drift loads the
  /// sqlite3 WASM module and its background worker from assets in `web/`. They
  /// are ignored on native platforms (macOS/iOS/Android), so passing them
  /// unconditionally is safe.
  static QueryExecutor _openDefault() {
    return driftDatabase(
      name: 'engram',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
