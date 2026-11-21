# TEMPER.md — sync clocks (issue 171 + the whole-graph save)

**Overall verdict:** RECAST (4 of 4 families)
**Struck:** dt-1795243322, families seated: Maxwell + Noether, Carnot, Tesla  (Wu disabled)

> **Note on the bundled probe.** Noether and Carnot both found the bundled `stale_save_probe_test.dart` vacuous: its save sat behind `if (graphA.topics.isNotEmpty)`, which never holds. They are right about that file. It was the *control* variant (save disabled), bundled by mistake instead of the failing variant. The regression test now on branch `fix/save-stamps-untouched-rows` (`test/storage/drift/changeset_test.dart`, "an unrelated save on one device keeps a review made on the other") runs the save unconditionally and fails on unchanged code: expected stability 40.0, actual 12.5. The diagnosis stands; the bundled evidence did not show it.

## Per-family verdicts
| Family | Verdict | One-line |
|--------|---------|----------|
| Maxwell (Claude) | RECAST | Layer 1's equality diff guards the snapshot `save()` instead of deleting it, and can't tell a change from a stale copy. |
| Noether (DeepSeek) | RECAST | Same producer kept; plus a schedule winner can resurrect a tombstone, and two clocks have no stated merge rule. |
| Carnot (GPT) | RECAST | Snapshots can't recover intent; legacy writers stay unsafe; the same-node echo filter drops composite rows; card identity across edits is undefined. |
| Tesla (Grok) | RECAST | Absence-deletion is live, not hypothetical; two clocks on one row still merge by whole-row replace; re-extraction is the dual writer. |

## Fatal flaws (deduped, most-severe first)
1. **The snapshot `save(KnowledgeGraph)` is the producer, and layer 1 only guards it.** An equality diff reads a stale snapshot as a change, stamps it fresh, and erases the review anyway; the same API infers deletion from absence. Raised by all four. DISPOSITION: fold. Layer 1 becomes explicit mutations (upsert what the caller changed, tombstone only the ids it names); the equality diff is never built and `_tombstoneOrphans` is deleted. Whole-graph replace survives only as an explicitly named seed/restore into an empty database.
2. **Absence-deletion is live, not "plausible".** Fire-and-forget saves (`upsertTopic`, `backfillCollectionInfo`), the topic auto-migration in `build()`, and staggered ingest all hand `save()` a possibly stale complete graph. Raised by Noether, Carnot, Tesla (and Maxwell). DISPOSITION: fold. A must-fail-then-pass interleaving test (snapshot, merge a peer row, then commit the unrelated mutation) goes in the layer-1 PR, and explicit deletes are unconditional.
3. **Two clocks on one row, merged by whole-row replace, reintroduce the bug.** `insertOrReplace` writes both groups (and resets absent columns to NULL); a schedule winner can carry `is_deleted = false` and resurrect a tombstone; the same-node echo filter would drop a row mixing A's content with B's schedule; `getLastModified`, `purgeTombstones` and clock reception all assume one clock. Raised by Noether, Carnot, Tesla. DISPOSITION: fold. **Recast option A as two tables** (quiz content, quiz schedule), each with one clock whose meaning is "this row last changed". The existing row-level merge, echo filter, purge and changeset machinery then stay correct unchanged, and the four-way column merge never has to be written.
4. **Mixed builds: an old writer keeps the bug alive.** Reading a legacy single-`hlc` row as "both groups changed" grants a stale whole-graph save full authority. Raised by Maxwell, Carnot, Tesla. DISPOSITION: fold. Layer 2 ships only once every syncing device runs layer 1; legacy single-clock rows are decoded only from `sync_log` history up to the cleanup horizon. Live pushes from below the minimum version are refused, not merged.
5. **"Not sent" vs null for `rubric`.** Noether wants a third wire state; Tesla and Carnot want complete group payloads so the question can't arise. DISPOSITION: fold Tesla's version. With separate tables, a content row always travels whole; the only gap is pre-https://github.com/enspyrco/engram/pull/146 history, handled at the decode boundary. No third wire state.
6. **Card identity across content edits.** Does a changed question keep its old stability? Re-extraction of the same id writes both content and a default schedule. Raised by Carnot, Tesla. DISPOSITION: **named question for Nick** (below). Until decided, extraction creates a schedule row only for a new id and never overwrites an existing one.
7. **Option B addresses a different harm.** Review events fix concurrent same-card review, not broad-overwrites-narrow. Raised by Maxwell; Carnot and Tesla agree to defer. DISPOSITION: fold one sentence; stays deferred, as an accepted limitation.

## What holds
- The diagnosis: one stamp on every row turned per-row last-writer-wins into per-save last-writer-wins (all four).
- Content and scheduling are two writers, matching `docs/CRDT_SYNC_ARCHITECTURE.md:51` (all four).
- `is_deleted` belongs to content (all four).
- Order: layer 1, then layer 2, then the rubric backfill (Tesla, Noether).
- Option B is the honest end state for scheduling, deferred (all four).

## Open question for Nick
- When re-extraction changes a card's question or answer under the same id, is it the same card (keep its review history) or a new one (fresh schedule)?

## Disposition
RECAST: fold flaws 1–5 and 7 into DESIGN.md. Layer 1 is now unanimous and can be built without a re-strike. Re-strike layer 2 (two tables) before it is built.

---

## Per-family strikes (arrival order)

## MaxwellMergeSlam's Design Strike

**Verdict:** RECAST

**Summary:** The note correctly finds the producer (a whole-graph save that stamps rows it never touched) and then, in layer 1, guards it with an equality diff instead of deleting it — and that diff cannot tell "the caller changed this row" from "the caller's copy is older than the database", so the bug it reproduces survives on every stale snapshot.

**Producer first:** The harm: a review (or a content write) made on one device disappears on every device. The trigger is external and unavoidable — two devices write before they sync. The producer is ours: `save(KnowledgeGraph)` is a snapshot API, so every caller hands over the whole graph and the repository has to *infer* what happened from its shape: "present ⇒ changed now" (today), "differs from the DB ⇒ changed now" (layer 1), "absent ⇒ deleted now" (`_tombstoneOrphans`, section 4). Every one of those inferences is a check standing in for a fact the caller already had. The producer can be removed: replace `save(graph)` with change-scoped writes that state the change — `applyExtraction(documentId, upserted, removedIds)`, `upsertTopic(topic)`, `removeTopic(id)`, `splitConcept(...)`, `backfillCollectionInfo(...)` — each stamping exactly the rows (and, after layer 2, exactly the column group) it names. Then the equality diff and the absence-tombstone both become unnecessary, and sections 1 and 4 close with one structural change instead of one check each.

**Fatal flaws:**
- **[check whose producer could be removed / missing failure mode] make "an untouched row gets a fresh clock" impossible: delete the snapshot `save(graph)` and give each caller a change-scoped write; then layer 1's equality diff and `_tombstoneOrphans` become unnecessary.** As designed, layer 1 compares the caller's snapshot with the stored row. If a sync merges B's review into the DB after the caller took its snapshot (the `staggeredIngestExtraction` window the note itself describes in section 4, or any `unawaited(repo.save(currentGraph))` racing a periodic sync), the stale snapshot *differs* from the DB, the diff reads that as a change, stamps the stale scheduling fields with a fresh clock, and the review is erased again — on every device. Section 2 claims "This alone makes the probe pass"; true for the probe, which never merges mid-save, false for the race the note names two sections later. Sections 1 and 4 are the same producer; the note splits them and fixes each with a different check.
- **[unstated assumption] Layer 2 assumes the per-group stamping can be derived inside the repository.** It can't, for the same reason: "which group changed" from a snapshot diff is again an inference. A review must stamp `schedule_clock` *because it is a review*, a rubric backfill must stamp `content_clock` *because it is a content edit* — the clock group is a property of the writer's intent, not of a diff. The note should say each change-scoped write declares its group, and the rubric backfill (the reason this note exists) must be specified as such a write, not as a `save(graph)` with a changed field.
- **[under-counted blast-radius] The mixed-build window is not just "rubric key missing".** An old build keeps running today's `save()`, so it keeps stamping every row it holds with one fresh `hlc`; under the proposed back-compat (`hlc` ⇒ both clocks) every such row arrives as a winning content write *and* a winning schedule write. Until every device updates, an old device erases reviews and backfilled rubrics exactly as now. Name it: the fix is only as strong as the oldest build still syncing; consider refusing (or quarantining) pushes from builds below the clock-aware version rather than merging them as full-row wins.
- **[wrong option-frame, minor] Option B is framed as "later, if concurrent review shows up".** The probe's harm is not concurrent review of the same card; it's a broad writer overwriting a narrow one. Option B fixes a different, rarer harm. That's fine, but say so, so nobody later reaches for B believing it addresses issue 171.

**What holds:**
- Opening with the producer and proving it with probe + control: the diagnosis is real and reproduced, not argued.
- Content vs scheduling are genuinely two writers on one row; two clocks on quiz items only (single-writer tables keep one clock) is the right granularity.
- Retiring the `hlc` name on quiz items; reading old `hlc`-only rows as both clocks so `sync_log` history replays with its original meaning.
- `is_deleted` in the content group (deletion is an extraction decision; a later review of a tombstone stays tombstoned).
- Recognising `docs/CRDT_SYNC_ARCHITECTURE.md:51` already specified the split — this is drift repair, not invention.

**If RECAST, what to fold back:**
- Rewrite section 2: layer 1 = replace `save(KnowledgeGraph)` with change-scoped repository writes (one per caller in the section 1 table), each stamping only the rows it names. Drop the equality diff. Keep `save(graph)` only for the Firestore seed into an empty DB (no peer state to clobber), or rename it to `seedEmpty` so no caller can reach for it.
- Merge section 4 into section 2: deletion becomes explicit (`removedIds` from the extraction), so `_tombstoneOrphans` goes; the absence-deletion test becomes the regression test for that.
- Layer 2: each change-scoped write declares its clock group; specify the rubric backfill as a content-group write.
- Add a "mixed builds" subsection: what an old build does after the change, and whether to refuse its pushes.
- Option B: one sentence stating it addresses concurrent same-card review, not the broad-overwrites-narrow harm.


## NoetherNullPointer's Design Strike

**Verdict:** RECAST

**Summary:** The design correctly names the broken invariant — *a row's clock must advance iff that row changed* — but it repairs the symptom (stamping) while keeping the producer (`save()` consumes a whole-graph snapshot and reads meaning into its shape), so the same invariant stays broken on the paths the design doesn't draw.

**Producer first:**

Three bad outcomes, and the producer of each is ours:

- **A review is erased on every device.** Trigger: a study session on the phone plus an unrelated ingest on the laptop. Producer: `save()` computes one `_stampHlc()` and writes it onto *every* row of the incoming graph (`drift_graph_repository.dart`, `save()`/`_stampHlc`), so an untouched `q1` gets a clock later than B's review and wins LWW. **Removable?** Yes. The producer is not "stamping" — it is *being handed unchanged rows*. If callers wrote precisely (upsert the concept, upsert the topic, delete the named cards) there would be no unchanged rows in the call and no diff to compute. Layer 1's "compare and skip" is a guard bolted onto a producer that should not exist. **This is Fatal flaw #1: make the whole-graph save impossible; then change-detection becomes unnecessary.**

- **A deleted card resurrects from a late review.** Trigger: B reviews `q1` before seeing A's tombstone. Producer: `mergeChangeset`/`_batchMerge` applies winners with row-level `InsertMode.insertOrReplace`, which writes the *whole row*, `is_deleted` included. Section 3 promises "a review arriving for a tombstoned card … the card stays deleted," but nothing in the described merge makes that true — the schedule winner carries `is_deleted = false` and replaces the tombstone. **Removable?** Yes: the merge must be group-aware and never let a schedule-clock winner write a content column. Name it in the design or it will be built as row-level LWW with two clocks and it will resurrect.

- **A content merge from an old peer wipes a local rubric.** Producer: `_quizItemFromJson` collapses an absent key and an explicit `null` to the same `rubric: null` (`graph_changeset.dart`). **Removable?** Yes — the wire type needs a third "not sent" state, which the design already suspects. It is not an open question; it is a producer.

No check is added for the deletion-inference problem; the design only proposes a test (section 4). That omission is Fatal flaw #3 below.

**Fatal flaws:**

- **Wrong producer kept, guard added in its place (Section 2, class: symptom-fix).** The root is "a caller hands `save()` a whole `KnowledgeGraph` and `save()` treats its *shape* as truth." Layer 1 keeps that root and diffs against the DB to compensate — the exact shape the prompt warns against ("a hole in a guard is evidence the guard is the wrong shape"). Section 4 even admits it: *"save() reads meaning into the shape of a whole-graph snapshot."* The design says this in one section and then ships a different fix in another. Remove the whole-graph save; Layer 1's diff and `_tombstoneOrphans` both dissolve.

- **Under-counted blast radius on absence-deletion (Section 4, class: concurrent-arrival).** Section 4 scopes the orphan-tombstone hazard to `staggeredIngestExtraction`'s 250 ms window and says "I haven't reproduced this." But `backfillCollectionInfo` and `upsertTopic` both call `repo.save(newGraph).catchError(...)` **fire-and-forget** (`knowledge_graph_provider.dart`). Two such saves, or one such save racing a `mergeChangeset` transaction, both produce the same outcome: a `newGraph` captured before the peer's rows arrived runs `_tombstoneOrphans` and tombstones rows a concurrent writer just added — with a fresh clock, so the deletion wins everywhere. The producer is overlapping whole-graph saves, not one slow loop. The test in section 4 will not catch it because it will not interleave the fire-and-forget saves.

- **The central evidence is vacuous (probe test, class: broken verification).** The probe's only save is guarded by `if (graphA.topics.isNotEmpty)`. Device A starts with **no** topics (`start()`), so the guard is false, the save never runs, and the assertion passes with or without Layer 1 — as does its "control." The design's "shown, not argued" is therefore not shown. A regression test whose triggering step is skipped cannot certify the fix that makes the step safe. (The comment says A "adds an unrelated concept"; the code adds a *topic* behind a guard that forbids it — the trigger and the producer were mixed up.)

- **Two clocks without a stated merge algebra (Section 3, class: unstated assumption).** "Merge each group on its own clock" is asserted, never specified. The row-level `_batchMerge` currently compares one HLC and does `insertOrReplace`. Section 3's tombstone rule, the `is_deleted`-belongs-to-content rule, and the back-compat rule (`hlc` = max of the two on write, read as both clocks on the wire) are mutually consistent only if the merge is rewritten to be field-group-scoped and to *not* overwrite the losing group's columns. That is a load-bearing change the design files under "schema migration … wire read and write," where it will be missed.

**What holds:**

- The core diagnosis is sound and correctly evidenced by the described two-DB scenario: `save()` over-stamps, per-row LWW degrades to per-save LWW, reviews lose. The invariant is real.
- Two clocks on quiz items (content vs schedule) is the right *decomposition* for issue 171's content-vs-review collision; `is_deleted` genuinely belongs to content.
- The back-compat read (a lone `hlc` is read as both clocks; keep emitting `hlc` = max while old builds can pull) is correct and preserves history replay.
- Option B (reviews as an append-only set, scheduling as a deterministic fold) is correctly identified as the CRDT-native end state; keeping it non-blocking is right.
- Naming `hlc` away on the quiz table to prevent the old meaning from being reused is a good invariant-preserving move.

**If RECAST, what to fold back:**

- **Make Fatal flaw #1 the primary change.** Rewrite Section 2's framing: the fix is to stop handing `save()` a whole graph. Give `GraphRepository` precise writes (`upsertConcept`, `upsertTopic`, `upsertQuizItem`, `deleteQuizItemsForDocument(ids)`, `deleteRelationshipsFor(ids)`) and migrate `ingestExtraction`, `backfillCollectionInfo`, `upsertTopic`, and the migration path to them. State explicitly that with precise writes, per-row change-detection and `_tombstoneOrphans` are *deleted*, not guarded. Keep `save()` only if a caller genuinely needs bulk-replace semantics, and say which.
- **Move the absence-deletion fix out of "if it reproduces."** Explicit deletes are not conditional on a staggered-ingest repro; the fire-and-forget `save` calls in `backfillCollectionInfo`/`upsertTopic` are the reproducer. Fold the concurrent-save interleaving test into the Layer-1 PR and commit to explicit deletes.
- **Specify the merge algebra for two clocks.** State that `mergeChangeset` selects a *group* winner per clock and writes only that group's columns, that a schedule winner never writes `is_deleted` or content fields, and that `maxHlc` is `max(content_clock, schedule_clock)` per row and for the changeset.
- **Promote "not sent" to a wire-type change, not an open question.** Add a third state for `rubric` (and any future added column) so an old peer's content winner cannot null a local value; delete the `_quizItemFromJson` absent→null collapse.
- **Fix the probe.** Remove the inverted `topics.isNotEmpty` guard so the save actually runs; add the control as a separate test, not an aside. The regression test is the deliverable; a vacuous one certifies nothing.

## CarnotCodeCarver's Design Strike

**Verdict:** RECAST

**Summary:** The diagnosis is sound; the proposed boundary is not. Comparing snapshots cannot recover write intent, and backward-readable JSON does not make old writers safe. Recast around explicit mutations, independently merged registers, and a defined upgrade boundary before the rubric backfill. No real engine matches the Carnot cycle; a reviewer's job is to say how far short we are. Here, stale snapshots remain an entropy pump.

**Producer first:** The harm is losing reviews, edits, or whole entities after an unrelated save. Concurrent activity is the trigger. The producer is save(graph): it promotes every difference between a caller's snapshot and current storage into a fresh authoritative write, and promotes absence into deletion. The proposed equality check suppresses identical payloads but preserves that producer. Remove snapshot replacement from ordinary mutation paths: submit explicit field-group updates and explicit deletions, applied transactionally to current storage. Incoming wire data still requires decoding and validation because independently versioned peers supply bytes; that boundary cannot be deleted.

**Fatal flaws:**
- make unrelated review loss and accidental deletion impossible: replace whole-graph saves with explicit content, scheduling, metadata, membership, and deletion mutations; then snapshot-equality guards and orphan inference become unnecessary. Comparing with current storage inside a transaction does not establish intent. Load snapshot S, merge a newer review into storage, then save S with a topic added: the stale scheduling fields now differ from storage, so layer 1 stamps them as a new change and erases the review. Per-group comparison repeats the same mistake. A transaction serializes the overwrite; it does not make the snapshot current.
- The supplied probe does not execute its alleged producer. start() creates no topics, but the save is conditional on graphA.topics.isNotEmpty. That condition is false, so the advertised regression and its no-save control exercise the same path. The supplied artifact does not substantiate the claimed reproduction or layer-1 fix.
- Mixed-version compatibility preserves parsing, not correctness. An old writer still restamps the whole graph and emits only hlc; interpreting that as both clocks grants stale content and scheduling fresh authority. An old reader also collapses independently merged groups back into one row. Keeping an hlc alias prevents a decoder crash while leaving the original data-loss mechanism operational. Historical legacy rows are replayable under legacy semantics; they do not establish safe coexistence with active legacy writers.
- Missing rubric plus a shared content clock breaks convergence. Two replicas with different local rubrics can accept the same winning legacy content payload without a rubric key, each retain its local rubric, and finish with equal content clocks but different content. Full-row serialization can then advertise those different rubrics under the same clock, and equal-clock merges cannot reconcile them. Value.absent() is also lost when decoded into the current nullable DriftQuizItem representation. A presence flag alone does not supply the missing version semantics.
- The generic same-node row filter becomes invalid for composite rows. A can retain its own content update while merging B's newer scheduling update, then publish that combined row with hlc=max(content_clock,schedule_clock). B sees its own node in the maximum clock and the existing filter discards the entire row, including A's unseen content. Echo suppression must not discard independently owned register values; suppress same-node clock reception separately from data merging.
- Two clocks assume content and scheduling are semantically independent without defining card identity across edits. Replacing a question while preserving its old stability may attach learning history to a different retrieval task. Conversely, an intended content-plus-schedule reset can be split by a concurrent review. Define which edits preserve identity and how incompatible revisions are represented before choosing the merge groups.
- The migration blast radius exceeds getChangeset and maxHlc. getLastModified, purgeTombstones, generic merging, and clock reception all currently assume one quiz-item hlc. A scheduling update to a tombstone makes max(content,schedule) unsuitable as its deletion age. The design needs an explicit deletion clock source, acknowledgement rule, and stale-device recovery policy; a local bookmark alone is not evidence that every replica received a deletion.

**What holds:**
- The central diagnosis is correct: saving unrelated entities must not advance their conflict-resolution clocks.
- Independent content and scheduling registers can prevent a rubric update and a review from overwriting each other, once producers express intent and register payloads have deterministic merge semantics.
- Putting is_deleted in content can preserve deletion against scheduling-only updates. A separate deletion clock is not automatically necessary; explicit resurrection and reclamation semantics are.
- Review events are a reasonable future model, but they do not repair stale content writes, inferred deletion, or unsafe legacy writers. Deferring that larger change is defensible if concurrent-review loss is an explicitly accepted limitation.
- Dijkstra: "Simplicity is prerequisite for reliability." Removing snapshot authority deletes more failure machinery than adding increasingly elaborate comparisons.

**If RECAST, what to fold back:**
- First replace ordinary save(graph) calls with explicit mutations. Extraction should name its replacement scope and deleted IDs; topic edits should write topics; reviews should write scheduling only. Persist extraction independently of its animation frames. Reserve whole-database replacement for an explicitly defined import or restore operation.
- Correct the probe so the unrelated save runs unconditionally, with deterministic clock control. Add the stronger interleaving: capture snapshot, merge a review or new entity, then commit the unrelated mutation. Assert that the review survives and the entity remains active.
- Define the actual replicated registers and card revision rules. Separate content and scheduling tables are worth considering because their existing row merge boundaries can then match their ownership; two clocks in one row remain viable if all merge and serialization paths honor both.
- Choose a safe rollout boundary: require legacy writers to upgrade, or isolate protocol generations with an explicit migration bridge. Document historical-log decoding separately from permission for old builds to continue writing.
- Give rubric updates deterministic version ownership. Options include an independently versioned rubric register or a migration that produces complete, canonical content states. Preserve absent, null, and present through the wire representation where needed, without allowing equal register clocks to identify different authoritative values.
- Specify both-clock handling for selection, maxima, clock reception, merges, and metadata. Remove whole-row same-node filtering. Base quiz tombstone reclamation on the deletion's content clock plus an actual acknowledgement or rebootstrap policy.
- Before backfill, demonstrate convergence under reordered and repeated delivery, including mixed-origin clock groups, missing versus null rubric, deletion plus review, and content revision plus scheduling reset.


Tesla: "If you want the secrets of the universe, think in energy, frequency and vibration."

## Tesla, the Arc-Prophet's Design Strike

**Verdict:** RECAST

**Summary:** Layer 1 is the true harmonic, but two clocks on one row will sing the old overwrite at 3am the first time merge still replaces a whole row, and `save()`-as-snapshot will keep tombstoning peers in a race the design treats as weather.

**Producer first:** The harm is a review (or a peer's new card) vanishing on every device. Triggers are ordinary: a five-minute sync, an ingest, a staggered animation, an old build still in a pocket. The producers are ours: (1) `DriftGraphRepository.save` treating a `KnowledgeGraph` snapshot as the complete write-set — one HLC on every row, `_tombstoneOrphans` for every absence; (2) row-level `insertOrReplace` / `_batchMerge` while two writers share one quiz-item row. Both can be made unable to produce it: make `save` a patch (upsert these rows, delete these ids) so unchanged rows never enter the write, and give each writer-group its own relation (or a column-group merge that cannot represent a whole-row winner). The skip-if-equal test and "legacy `hlc` means both clocks" decoder then become unnecessary. The design still adds those checks on top of the snapshot API.

**Fatal flaws:**
- **Snapshot-save is still the producer (DESIGN.md §§1–2, 4; `save` + `_tombstoneOrphans`; `staggeredIngestExtraction`).** Layer 1 is an equality guard inside a method whose contract is "this graph is the world." That guard stops the stamp; it does not stop the delete. Concurrent `mergeChangeset` during any `save(state)` — ingest, topic upsert, collection backfill, Firestore seed, the topic auto-migrate in `build()` — leaves peer rows absent from an in-memory frame. They are tombstoned with a fresh clock and the deletion wins everywhere. This does not wait on `ref.invalidate`. Provider `state` is not a `watch()` of the DB; a 3-second stagger and a resume-sync are enough. The CRDT note already forbade `save` with a partial graph; a complete-but-stale graph is the same oscillator. Section 4 files this as "plausible, untested." Naming it does not close it. Make absence-deletion impossible: callers pass the ids they mean to tombstone (extraction already knows which cards a document replaced); then `_tombstoneOrphans` leaves the path.
- **Two clocks on one row, whole-row merge (DESIGN.md §3 Option A; `mergeChangeset` / `_batchMerge`; `GraphChangeset`).** "Merge each group on its own clock" and `getChangeset` selecting the **whole** quiz row when **either** clock is past the bookmark cannot both mean `insertOrReplace` of that row. A later `content_clock` from laptop ingest still carries laptop's stale `stability`. One replace, and the phone's review is glass again — the same frequency as issue 171, now with two named tuning pegs. `insertOrReplace` with `Value.absent()` resets the other group to SQL defaults; that is §6's first question, and it is already a yes. Fold: either split `quiz_content` / `quiz_schedule` so existing row-LWW stays true (one clock per relation, six tables' machinery still hums), or write the 4-way merge in the design (content win / schedule win / both / neither) as a column update, never a row replace. Two clocks without that sentence are costume jewelry.
- **`DriftQuizItem` cannot say "not sent" (DESIGN.md §3 missing key; `GraphChangeset._quizItemFromJson`).** A materialized row has `rubric: null`, not absent. The decoder already maps a missing key to null; `toInsertCompanion` then writes NULL and a winning content group wipes the local rubric. A third wire state for every field is the wrong extra oscillator. Send **complete groups** when that group's clock advances; keep a one-field historical hole for pre-https://github.com/enspyrco/engram/pull/146 `sync_log` rows at the companion boundary. Retire the open question; do not grow the wire.
- **Legacy `hlc` as both clocks is only safe after every producer has Layer 1 (DESIGN.md §§3, 5, 6).** An old build that still stamp-saves the graph emits a fresh `hlc` on untouched quiz items. New merge hears "both groups changed" and the review dies in the mixed window. History replay wants that old meaning; live mixed sync cannot. State the invariant: Layer 2 ships only when min client is Layer 1, and the `hlc` read-as-both path dies when `cleanup(beforeHlc)` has eaten pre-split `sync_log` plus that min version. Until then the fossil name `hlc` on the wire will re-summon one-clock code.
- **Re-extraction is the writer that touches both groups (DESIGN.md §6 Q4; `ingestExtraction` / `withNewExtraction`).** Same card id, new `QuizItem` with default FSRS, Layer 1 sees inequality, stamps, remote schedule lost — even after two clocks if "create" stamps `schedule_clock`. Rubric backfill is content-only; re-ingest of the same document is the 3am that follows the backfill. Specify: `schedule_clock` only when the row does not exist, or when question/answer identity actually changed; rubric-only and concept-move stay content.

**What holds:**
- Section 1 is load-bearing: one stamp on every row made per-row LWW into per-save LWW; the probe plus control is a real frequency measurement, not a parable.
- Layer 1 as the first PR, no wire change, mixed Layer-1 builds safe, probe as regression — that is the note that should ship before anyone names a second clock.
- Content vs scheduling as two writer-groups matches `docs/CRDT_SYNC_ARCHITECTURE.md` ("union for creation, LWW for scheduling fields") and matches why reviews are the victims.
- `is_deleted` in the content group is right for one person, two devices: a review may write into a tombstone; resurrection is a later content write. Concurrent question-edit vs delete is ordinary content LWW — say so, do not add a third clock.
- Option B as a later fold (`schedule_clock` goes dead) is the honest CRDT; do not pull it forward for issue 171.
- Order: Layer 1 → Layer 2 → rubric backfill. That sequence is the only one that does not feed the backfill into the bug.

**If RECAST, what to fold back:**
- **§2 / §4 / §5.1:** Change the `save(KnowledgeGraph)` contract to a patch: upsert the entities the caller changed; tombstone only explicit ids. Put the absence-deletion probe in the Layer 1 PR as a **must-fail-then-fix**, not a weather report. `staggeredIngestExtraction` persists without reading completeness from the shape of `state`.
- **§3 Option A:** Recommend **two relations** (content row, schedule row) over two clocks on one row, so `_batchMerge` stays row-LWW and `hlc` never needs to be renamed-and-kept. If you keep one table, write the 4-way column merge, forbid `insertOrReplace` for quiz items, and require `insertOnConflictUpdate` / targeted UPDATE per group. Update `getLastModified`, `purgeTombstones` (purge quiz tombstones on `content_clock`), and `receive()` (advance from the max of both) in the same section — they are silent today.
- **§3 wire:** Full group payload when that group wins. Missing `rubric` key: `Value.absent()` at merge, not a third wire type. `hlc` back-compat: write until min client is Layer 2; read until `sync_log` cleanup horizon; never decode live single-`hlc` rows as both groups unless the sender is known Layer 1 (changeset contains only actually changed rows).
- **§3 producer rules:** One `_stampHlc()` reading per transaction, assigned only to groups that changed; extraction stamps `schedule_clock` only on insert-of-new-id (or true question/answer identity change).
- **§6:** Answer the four questions in the doc; do not leave them as temper bait. (1) `insertOrReplace` + absent = NULL, so Layer 2 cannot use it. (2) `is_deleted` stays content. (3) Back-compat ends at min-client + `cleanup` horizon. (4) Re-extraction is the dual writer; schedule stamps only on create/identity-change.
