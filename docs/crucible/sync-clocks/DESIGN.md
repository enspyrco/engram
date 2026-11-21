# Sync clocks: what a row's timestamp should mean

Design note for https://github.com/enspyrco/engram/issues/171 and https://github.com/enspyrco/engram/issues/173. Round 2, 2026-11-21, after a 4-of-4 RECAST (`TEMPER.md`). It must settle before the rubric backfill that `docs/crucible/dialogue-sessions/TEMPER.md` lists as a prerequisite for the assessor.

## 1. The producer: where a row gets its timestamp

Sync is last-writer-wins per row. Each row carries one clock string (`hlc`), and when two devices disagree about a row, the one with the later clock wins and replaces the whole row. For that to be correct, a row's clock has to mean **"when this row last changed."**

It doesn't. `DriftGraphRepository.save(graph)` (`lib/src/storage/drift/drift_graph_repository.dart:109`) takes one fresh clock reading and writes it onto **every row in the graph**, changed or not:

```dart
final hlc = _stampHlc();
batch.insertAll(_db.driftQuizItems,
    graph.quizItems.map((q) => q.toCompanion(hlc: hlc)).toList(), ...);
```

So the clock on a row actually means **"when this device last saved anything."** Per-row last-writer-wins becomes per-save last-writer-wins over the whole graph: the device that saved most recently wins every row it holds, including rows it never touched.

The same method also decides deletion from the snapshot's shape: `_tombstoneOrphans` marks every active row missing from the graph it was handed as deleted, with the same fresh clock.

Full-graph `save` runs on every ingest and on several smaller edits:

| Caller | File |
|---|---|
| `ingestExtraction`, `staggeredIngestExtraction` | `lib/src/providers/knowledge_graph_provider.dart` |
| `splitConcept`, `backfillCollectionInfo`, `upsertTopic` (and topic delete) | same |
| topic auto-migration in `build()` | same |
| `startIngestion`, `startTopicIngestion` (collection backfill) | `lib/src/providers/ingest_provider.dart` |
| Firestore seed | `lib/src/providers/graph_store_provider.dart` |

Reviews are the exception: `updateQuizItem` stamps only the one row (`drift_graph_repository.dart:327`). That makes reviews the main victims, because they are the small precise writes that a broad save then overwrites.

### Shown, not argued

Regression test "an unrelated save on one device keeps a review made on the other" in `test/storage/drift/changeset_test.dart` (two in-memory databases, changesets sent through JSON as `FirestoreSyncTransport` does):

1. A and B start in sync.
2. B reviews card `q1` (stability 12.5 → 40.0).
3. A, before syncing, renames a topic and saves. `q1` is untouched on A.
4. Sync both ways.

Result on unchanged code: `q1` on both devices has stability **12.5**. B's review is gone everywhere. **Control:** the same test with step 3's save skipped, and every assertion still running, passes, so the save is the cause. (The first temper bundled the control variant by mistake; see `TEMPER.md`.)

Today this is an ordinary two-device day: study on the phone on the train, then ingest a document on the laptop before the five-minute sync fires.

### The original design said otherwise

`docs/CRDT_SYNC_ARCHITECTURE.md:51` specifies quiz items as *"Union for creation, last-write-wins for scheduling fields … uses the most recent review timestamp."* That separates the two concerns. The implementation collapsed them into one row clock, and then let any save advance that clock. Issue 171 is the second half of that drift; this section is the first half.

## 2. Layer 1: writes that say what they change (no schema change, no wire change)

Round 1 proposed keeping `save(graph)` and skipping rows equal to the stored ones. All four reviewers rejected it, and they were right: a comparison can't tell "the caller changed this" from "the caller's copy is older than the database". If a sync merges B's review after A took its snapshot, A's stale fields differ from storage, look like a change, get a fresh clock, and erase the review anyway. The caller is the only one who knows what it changed, so the caller says.

**Delete the snapshot write.** `GraphRepository.save(KnowledgeGraph)` is replaced by mutations that each name their rows:

| Caller | Mutation |
|---|---|
| `ingestExtraction`, `staggeredIngestExtraction` | `applyExtraction(document, upserted concepts/relationships/quiz items, removed ids)` |
| `upsertTopic`, topic delete, topic auto-migration | `upsertTopics(topics)`, `removeTopic(id)` |
| `splitConcept` | already additive: `saveSplitData` |
| `backfillCollectionInfo`, collection backfill in ingest | `updateDocumentMetadata(documents)` |
| Firestore seed into an empty database | `seedEmpty(graph)`, which refuses a non-empty database |

Each mutation runs in one transaction with one clock reading, applied only to the rows it names. Nothing reads meaning from what's missing:

- **Deletion is explicit.** `withNewExtraction` (`lib/src/models/knowledge_graph.dart:91`) already decides which concepts, relationships and cards a re-extraction drops for a document; today it filters them out silently. It will also return their ids, and `applyExtraction` tombstones exactly those. That comparison is old graph vs new graph inside one pure function, not snapshot vs database, so it can only drop rows the caller knew about. `_tombstoneOrphans` is deleted.
- **Staggered ingest persists the extraction, not the last animation frame.** The animation stays in provider state only; the write is `applyExtraction` with the extraction result.
- **Merged rows survive.** Because no write carries rows it didn't change, a peer row merged mid-ingest is neither overwritten nor tombstoned.

**Tests in the same PR, each failing first on unchanged code:**

1. The section 1 regression test.
2. Absence-deletion interleaving: A takes a snapshot, B's new card merges into A, then A commits an unrelated mutation built from the snapshot. B's card stays active on both devices. This is a real path today through the fire-and-forget `upsertTopic` and `backfillCollectionInfo` saves, not only the staggered ingest. **Reproduced on `main`** (2026-11-21): the same scenario written against `save()` leaves A with `['c1']`, B's ingested `c9` tombstoned.
3. Re-extraction of a document removes exactly the cards it replaced and leaves cards from other documents alone.

## 3. Layer 2: the same card, two writers, two tables

A quiz item is written by two kinds of activity that don't know about each other:

- **Content**, written by extraction and editing: `question`, `answer`, `rubric`, `concept_id`, `predicted_difficulty`, `is_deleted`.
- **Scheduling**, written by reviewing: `interval`, `next_review`, `last_review`, `difficulty`, `stability`, `fsrs_state`, `lapses`, `review_count`.

With one row and one clock, a review on B (later) overwrites a rubric backfill on A (earlier), even though the two writes touch different columns. That's issue 171.

**Round 1 proposed two clocks on one row. The temper recast it as two tables**, `quiz_item_content` and `quiz_item_schedule`, sharing the card id, each with one `hlc` that once again means "this row last changed". Two clocks on one row would have needed a new merge that writes only the winning group's columns. `insertOrReplace` writes the whole row and resets absent columns to NULL; a schedule winner would carry `is_deleted = false` and resurrect a tombstone; the same-node echo filter would drop a row mixing A's content with B's schedule; and `getLastModified`, `purgeTombstones` and clock reception all assume one clock per row. With two tables, none of that changes: each table is an ordinary single-writer table, and the existing row-level merge, echo filter, purge and changeset code are already correct for it.

- **Deletion lives in content.** A review arriving for a deleted card updates the schedule row, and the card stays deleted because the content row says so. Resurrection needs a later content write. Tombstone purge for quiz items purges both rows by the content row's clock.
- **Who writes which row:** a review writes only the schedule row. Extraction writes the content row, and creates a schedule row only when the card id is new. It never overwrites an existing schedule row (but see the open question below). The rubric backfill is a content-row write.
- **Reading:** `load()` joins the two tables. A content row with no schedule row yet (the schedule hasn't synced) gets the default new-card schedule. A schedule row with no content row is not shown.
- **Rows always travel whole.** The question of "not sent" versus null disappears for new rows: a content row is complete whenever its clock advances. The only gap is `sync_log` history from before https://github.com/enspyrco/engram/pull/146, which has no `rubric` key; the decoder reads that one historical case as "leave the local value", at the decode boundary, with no third state on the wire.

**Migration.** Schema bump: copy each `drift_quiz_items` row into both tables, both with the old `hlc` (exactly the old meaning, so history replays correctly), then drop the old table.

**Mixed builds.** An old build keeps doing whole-graph saves, and an old row read as both content and schedule would hand a stale save full authority over both. So:

- Layer 2 ships only after layer 1 has been released and every one of the person's syncing devices has reported a layer-1 version. Each pushed changeset already records `nodeId`; it gains a `protocol` number.
- Old-shape `drift_quiz_items` rows are decoded only from `sync_log` entries older than the cut-over, up to the existing cleanup horizon. A live push from a build below the minimum protocol is refused and the device is told to update, not merged.

## 4. Option B: reviews as events (deferred, and why)

Scheduling state is really a summary of the reviews that happened. Store the reviews instead, as an append-only set (`review_id, quiz_item_id, rating, reviewed_at, desired_retention`), and compute FSRS state by replaying them in time order. Merging two append-only sets is just their union, so **two offline reviews of the same card both count**. Under layer 2, one of them is thrown away.

This fixes a different harm from issue 171: concurrent review of the *same* card, not a broad write overwriting a narrow one. For one person with two devices it's rare, so it's an accepted limitation for now, owned by this note. Layer 2's schedule table becomes a derived cache if B is built later. It doesn't block B.

## 5. Order of work

1. **Layer 1 PR** (https://github.com/enspyrco/engram/issues/173): the mutations in section 2, deletion of `save(graph)` and `_tombstoneOrphans`, and the three tests. No wire change.
2. Release layer 1; wait for every device on the protocol to report it.
3. **Layer 2 PR** (issue 171): two tables, migration, protocol number and refusal, `load()` join. Convergence tests sent through JSON: reordered and repeated delivery, deletion plus review, content edit plus review, pre-146 history row.
4. Then the rubric backfill, as content-row writes.
5. Option B only if concurrent same-card review loss is observed.

## 5a. What the code cage-match found: the clock is still per row (escalation)

PR https://github.com/enspyrco/engram/pull/174 hit the 3-round cap without a clean round. Rounds 2 and 3 found one class four times: a write carrying more than it changed (the whole topic at the end of ingest, the whole document row on backfill, the topic row on a link-only edit). Each was fixed by making the write column-scoped. Carnot's round-3 finding names why that can't be the end of it:

**The producer is the per-row clock itself.** A column-scoped write leaves the other columns as storage has them, which protects edits already merged. But it still advances the row's single clock, so an edit to a *different* field of the same row on another device, not yet synced, loses the whole row to it. Example: B renames topic t1; A, before syncing, marks t1 ingested; A's later clock wins t1's row, and B's rename is gone everywhere.

That is the same shape as issue 171 (content vs schedule on a quiz row), on topics and document rows too. Layer 2 as written fixes it for quiz items only, by splitting the table so each row has one writer. Before layer 2 is built, its temper should answer the general question: **per-field clocks (an LWW register per column) for every table, or a table split per writer where writers are few?** A per-field register makes "a write changes only its fields" true at merge time as well as at write time, and dissolves the column-scoping as a special case. Its cost is the wire format: each field travels with its own clock.

## 6. Card identity across re-extraction (decided 2026-11-21: middle path)

Today quiz ids are not stable: the extraction prompt reuses concept ids but invents quiz ids, and `withNewExtraction` drops every card on a re-extracted document's concepts, so any edit to a wiki page resets the review history of every card from that page.

Decision: the extraction prompt receives the document's existing cards (as it already receives concept ids) and reuses a card's id when the new card tests the same fact, flagging whether the answer's meaning changed.

- **Reworded, same fact:** keep the schedule. Only the content row changes.
- **Answer's meaning changed:** record a lapse, an FSRS "Again" at re-extraction time, which keeps difficulty, shrinks stability by FSRS's post-lapse rule, and brings the card due soon.
- **No match:** a new card with a fresh schedule; the unmatched old card is dropped.

Under layer 2, a reword is a content-row write only; a changed answer is a content-row write plus a schedule-row write. The open risk is whether Claude judges "same fact" reliably; text comparison can't, because Claude rephrases every time.
