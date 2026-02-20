# Engram

Flutter app that reads an Outline wiki, uses Claude API to extract a knowledge graph (concepts + relationships + quiz items), and teaches it back via spaced repetition (migrating from SM-2 to FSRS — see `docs/FSRS_MIGRATION.md`). Visual knowledge graph that "lights up" as you learn.

## Architecture
- **Models**: Immutable data classes with `fromJson`/`toJson` and `withXxx()` update methods
- **Scheduling Engine**: Currently SM-2 (pure function, no class state), migrating to FSRS (`fsrs` pub package). FSRS closes the extraction↔scheduling loop: Claude predicts quiz item difficulty at extraction time, FSRS uses it as initial D₀. See `docs/FSRS_MIGRATION.md`. Scheduling state lives on `QuizItem`. `scheduleDueItems` supports optional `collectionId` filter — unlocking remains graph-wide, only item selection is scoped
- **Graph Analyzer**: Dependency-aware concept unlocking, topological sort, cycle detection
- **Storage**: `GraphStore` — Firestore primary (`users/{uid}/data/graph/`), local JSON fallback (migrating to local-first Drift/SQLite — see `docs/LOCAL_FIRST.md`); `SettingsRepository` — API keys via `shared_preferences`; `UserProfileRepository` — Firestore user profiles; `SocialRepository` — wiki groups, friends, challenges, nudges; `TeamRepository` — network health, clusters, guardians, goals, glory board
- **Auth**: Firebase Auth with Google Sign-In + Apple Sign-In; `firestoreProvider` for injectable Firestore instance
- **State Management**: Riverpod (manual, no codegen) — `Notifier`/`AsyncNotifier` classes. Wiki group membership flows through a provider dependency chain: `wikiGroupMembershipProvider` (ensures `joinWikiGroup` before any Firestore listener) → `teamRepositoryProvider` → all team notifiers (storms, relays, goals, guardians, glory board). `socialRepositoryProvider` lives in its own file to avoid circular imports
- **Knowledge Graph**: Custom `ForceDirectedGraphWidget` with `CustomPainter` + Fruchterman-Reingold layout, nodes colored by mastery (grey→red→amber→green), team avatar overlay. Incremental layout: existing nodes are pinned as immovable anchors, new nodes animate into position via force simulation
- **Network Health**: `NetworkHealthScorer` computes composite health from mastery + freshness + critical paths; `ClusterDetector` finds concept communities via label propagation
- **Services**: `OutlineClient` (HTTP), `ExtractionService` (Claude API via `anthropic_sdk_dart`)
- **Social**: Wiki-URL-based friend discovery (SHA-256 hash of normalized URL), challenge (test friend on mastered cards) + nudge (remind about overdue) mechanics
- **Cooperative Game**: Guardian system (volunteer to protect concept clusters), team goals (cooperative targets with contribution tracking), glory board (leaderboard with guardian/mission/goal points), repair mission bonus scoring (1.5x interval for mission concepts)

## Screens
- **Sign In**: Apple + Google branded sign-in buttons (auth gate before main app)
- **Dashboard**: Stats cards, mastery bar, knowledge graph visualization
- **Quiz**: Collection filter dropdown → session mode → Question → Reveal → Rate (0-5) → Session summary
- **Ingest**: Collection picker → per-document extraction progress with live animated knowledge graph (new concepts settle into place via pinned force-directed layout)
- **Social** (was Friends): 3-tab layout — Friends (friend list + challenges + nudges) | Team (guardians + goals + missions) | Glory (ranked leaderboard)
- **Settings**: API key configuration (Outline URL/key, Anthropic key)

## Development
```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

## Testing
Tests mirror lib/src/ structure. Use `mocktail` for mocking HTTP clients. Widget tests override providers with `_PreloadedGraphNotifier` to avoid async I/O. Custom `ForceDirectedGraphWidget` settles via temperature annealing, so `pumpAndSettle()` works in all tests. Always handle all analyzer hints — never use `// ignore` comments; fix the root cause instead.

## Debugging Strategy
When something visual doesn't work, **isolate → simplify → layer back in**:
1. **Isolate** — Create a standalone screen (like `GraphLabScreen`) with hardcoded test data. Remove providers, auth, network, and other moving parts. Wire it as the default tab so it opens immediately.
2. **Simplify** — Start with the absolute minimum: does a colored box render? Does a single node show? Build up from what works.
3. **Layer back in** — Add complexity one piece at a time (edges, labels, animation, interaction) so you can pinpoint exactly which addition breaks things.

This caught a `CustomPaint` sizing bug that was invisible in production (tight constraints from `Expanded` masked a `SizedBox.shrink()` child that collapsed to 0x0 under loose constraints).

## Synaptic Web Game Design

`docs/SYNAPTIC_WEB_GAME_DESIGN.md` contains the full creative vision for the cooperative network game. All phases complete and merged:
- Phases 1-3: Custom canvas + team overlay + catastrophe system (#32)
- Phase 4a: Guardian system + team goals + glory board (#42)
- Phase 4b: Relay challenges + entropy storms (#44)

## Architecture Decision Records

When starting a new session, remind the user about these architectural decisions:

- `docs/GRAPH_STATE_MANAGEMENT.md` — Analysis of graph-based state management options. Decision: stay with Riverpod, normalize incrementally. Split `graphStructureProvider` from quiz item state to avoid wasted recomputation.
- `docs/LOCAL_FIRST.md` — Local-first architecture plan. Decision: migrate to Drift/SQLite as primary storage, Firestore as sync peer. Device is source of truth; server handles compute, sync, and social coordination.
- `docs/CRDT_SYNC_ARCHITECTURE.md` — CRDT sync design for local-first. Knowledge graph operations map naturally to G-Set, LWW-Register, and G-Counter CRDTs. Cooperative game features are accidentally CRDT-native.
- `docs/FSRS_MIGRATION.md` — Migration from SM-2 to FSRS. Key insight: FSRS has a Difficulty parameter that is a property of the card (not the learner), so Claude can predict it at extraction time — closing the loop between extraction and scheduling that SM-2 forced open. Also enables per-concept `desired_retention` based on graph position, solves SM-2 ease hell via mean reversion, and gives cooperative game mechanics (guardians, repair missions) a principled scheduling foundation.

## Open Investigations

When starting a new session, prompt the user about these:

### ~~Graph-based state management vs Riverpod~~ ✓ RESOLVED
Investigated Feb 2026. Decision: stay with Riverpod, normalize incrementally. No graph DB or signal-based framework needed. The real fix is splitting `graphStructureProvider` from quiz item state so `ClusterDetector` and `GraphAnalyzer` don't recompute on every quiz review. See `docs/GRAPH_STATE_MANAGEMENT.md` for full analysis. Quick wins: `fast_immutable_collections` for O(1) structural sharing, `graphs` Dart package for topo sort, cached cluster detection.

### ~~Custom force-directed canvas vs flutter_graph_view~~ ✓ RESOLVED
Replaced `flutter_graph_view` with custom `ForceDirectedGraphWidget` (`CustomPainter` + Fruchterman-Reingold). Works directly with `Concept`/`Relationship` models, supports team avatar overlay, `pumpAndSettle()` works in tests, and glow effects are implemented. `GraphDataMapper` deleted.

### ~~Per-collection or wiki-wide graph?~~ ✓ RESOLVED
Graph remains wiki-wide (cross-collection merge is the right default for dependency resolution). Collection-scoped quiz sessions implemented: `DocumentMetadata` stores `collectionId`/`collectionName`, `scheduleDueItems` accepts optional `collectionId` filter, quiz screen has a collection dropdown. Unlocking is graph-wide; only item selection filters by collection. `availableCollectionsProvider` + `selectedCollectionIdProvider` in `collection_filter_provider.dart`.

### Manual quiz item creation
All quiz items are auto-generated by Claude. Should users be able to add their own? Would help fill gaps where the LLM misses nuance or where a user wants to test something specific. Could be a simple "Add card" button on the quiz screen or a concept detail view.

### Multiplayer / team mode
Implemented in Phase 6 as wiki-URL-based friend discovery with challenge + nudge mechanics. Expanded in Phase 4a with guardian system, team goals, and glory board. Friends who share the same Outline wiki URL are auto-grouped. Remaining questions: should friend discovery require explicit opt-in (#28)? Should mastery snapshots be more granular (per-collection)? Privacy controls for what friends can see?

### Sub-concept splitting
When a quiz card has multiple answers, users should be able to split the concept into sub-concepts and master each before unlocking the parent. This changes the graph structure during learning (not just at ingestion). Implementation should be local-first — restructuring is a personal, exploratory act that shouldn't require network connectivity.

### Cross-discipline semantic relationships
The knowledge graph should surface connections across disciplines (e.g., "thermodynamic entropy relates to information-theoretic entropy"). Typed relationships now implemented (#80): `RelationshipType` enum includes analogy, contrast, composition, and 4 others. Remaining: Claude-computed concept embeddings at extraction time (#39), cosine similarity for "related concept" suggestions. See `docs/GRAPH_STATE_MANAGEMENT.md` for embedding analysis.

### Local-first migration
Migrate from Firestore-primary to Drift/SQLite local-primary with CRDT sync. See `docs/LOCAL_FIRST.md` and `docs/CRDT_SYNC_ARCHITECTURE.md`. This is a multi-phase migration: dual-write → local-primary reads → CRDT sync → Firestore optional.

### FSRS migration (extraction↔scheduling closed loop)
Investigated Feb 15, 2026. Decision: migrate from SM-2 to FSRS. The key insight is that FSRS's Difficulty parameter is a property of the card itself — Claude can predict it at extraction time, closing a loop SM-2 forced open. Also enables per-concept `desired_retention` based on graph position (hub=0.95, leaf=0.85, guardian=0.97), solves ease hell via mean reversion, and replaces crude `1.5x interval` game mechanic hack with principled retention targets. Pure Dart `fsrs` package (v2.0.1, 160/160 pub points) available on pub.dev. 4-phase migration plan in `docs/FSRS_MIGRATION.md`. An `extracting-knowledge-graph` skill was created in `.claude/skills/` encoding the full extraction workflow — it will be updated with FSRS difficulty prediction guidelines.

### Feeding mastery back into Outline
Could concept mastery data flow back into the wiki? e.g., tagging pages as "well-understood by 80% of the team" or surfacing knowledge gaps ("nobody has mastered the CI/CD section"). Would need Outline API write access and a clear UX for what "team mastery" means.

## Review Tech Debt (Issues #6–#18)

When starting a new session, remind the user that there are open tech debt issues from cage-match code reviews. Key items by priority:

**Bug:** ~~#13~~ ✓ FIXED in PR #45
**Performance:** #8 (topo sort O(n)), #11 (graph animation battery), #14 (migrator memory)
**Architecture:** ~~#6~~ ✓ FIXED in PRs #45, #79 (DateTime.now injectable — model methods + provider calls + UI layer), #9 (startIngestion refactor), #12 (ensureSignedIn provider), #15 (destructive Firestore save)
**Quality:** #7 (mutable List on @immutable), #10 (magic numbers), #16 (auth_provider tests), #17 (test hygiene), #18 (bloated pubspec)

## Phase 6 Tech Debt (Issues #23–#31)

From cage-match reviews of the Firebase + Social PRs (#20–#22):

**Architecture:** #23 (extract GoogleSignIn to provider for testability), #25 (DateTime instead of String for timestamps in models), #26 (inject clock into SocialRepository — extends #6), #29 (migrate AsyncNotifier stream patterns to StreamNotifier)
**Security:** #30 (strip scheduling fields from challenge quiz item snapshot), ~~#31~~ ✓ FIXED in PR #45 (UUID for all entity IDs)
**Robustness:** #24 (debug assertion for unconfigured firebase_options.dart), ~~#27~~ ✓ FIXED in PR #45 (normalizeWikiUrl strips http/https scheme)
**UX:** #28 (consider explicit opt-in for wiki group friend discovery)

## Architecture Evolution (Issues #33–#41)

From the graph state management investigation and local-first architecture planning:

**Performance (quick wins):** #33 (`fast_immutable_collections` for O(1) structural sharing), #34 (cache ClusterDetector, only recompute on structural changes), #35 (adopt `graphs` Dart package for topo sort)
**Architecture (provider splitting):** #36 (split `graphStructureProvider` from quiz item state — single highest-impact optimization)
**Features (deep learning):** #37 (sub-concept splitting for multi-answer cards), ~~#38~~ ✓ DONE in PR #80 (typed relationships for cross-discipline connections), #39 (Claude-computed concept embeddings for semantic discovery)
**Architecture (local-first):** #40 (Drift/SQLite as primary storage), #41 (CRDT sync layer for multi-device consistency)

## Implementation Roadmap

Current state: App running on macOS. FSRS Phase 1 merged. Knowledge graph animation complete (fluid physics, centering gravity, responsive layout). Actively ingesting and testing.

### Completed
- ✓ Phase 4a — guardian system, team goals, glory board (#42)
- ✓ Quick wins #33-#35 — `fast_immutable_collections`, cached clusters, `graphs` package (#43)
- ✓ Phase 4b — relay challenges, entropy storms (#44)
- ✓ Tech debt sweep — #13, #27, #31, #6 model methods (#45, #46), #47 clockProvider for all DateTime.now() calls (#79)
- ✓ Collection-scoped quiz sessions — `DocumentMetadata` collection fields, scheduler filter, quiz screen dropdown
- ✓ Extraction knowledge graph skill — `.claude/skills/extracting-knowledge-graph/` encodes the full extraction workflow (prompts, tool schemas, relationship taxonomy, scheduling constraints) as a portable agent skill with progressive disclosure
- ✓ Outline wiki updated — `kb.xdeca.com` (was `wiki.xdeca.com`), `.env` updated with new URL and API key. `OutlineClient` still read-only; collection/document creation done via direct API calls
- ✓ Agent Skills course ingested — 11-video Anthropic course on agent skills ingested into Outline collection "Agent Skills with Anthropic". Catalyst for extraction skill and FSRS migration insight
- ✓ FSRS Phase 1 — `fsrs` package added, `difficulty` field on `QuizItem`, FSRS engine alongside SM-2 (#59)
- ✓ Full-screen static knowledge graph with collection filtering (#58)
- ✓ Incremental graph layout — preserve settled node positions across rebuilds, temperature scaling (#60)
- ✓ Pinned animate-in — existing nodes are immovable anchors, new nodes settle via force simulation. Ingest screen uses animated `ForceDirectedGraphWidget`
- ✓ Renamed "mind map" → "knowledge graph" across codebase and docs (#60)
- ✓ Velocity-based physics — d3-force style velocity integration with momentum and coasting (#63)
- ✓ Viscous edge damping — springs-in-water feel, prevents oscillation without slowing global motion (#67)
- ✓ Circle initial placement + pre-settle — nodes start on a circle, 60-step simulation before first paint (#68)
- ✓ Ingest graph session filtering — live graph shows only concepts from current ingestion session (#69)
- ✓ Centering gravity + dashboard layout sizing + relationship tap — gravity prevents edge drift, LayoutBuilder for responsive sizing, shared EdgePanel, edge tap on animated graph (#70)
- ✓ Typed relationships — `RelationshipType` enum (prerequisite, generalization, composition, enables, analogy, contrast, relatedTo) with type-based graph visualization (color-coded edges, dashed lines, arrowheads) and `tryParse`/`inferFromLabel` backward compat (#80)
- ✓ Wiki group membership provider — shared `wikiGroupMembershipProvider` ensures `joinWikiGroup` before team Firestore listeners start, preventing permission-denied errors. `socialRepositoryProvider` extracted to own file. Missing Firestore rules added for relays/storms. `joinWikiGroup` uses `SetOptions(merge: true)` to preserve `joinedAt` (#81)

### Next up
1. **#61** — Preserve team node positions across graph rebuilds

### Longer-term
4. **FSRS Phases 2-4** — Dual-mode scheduling, full migration, extraction-informed scheduling closed loop
5. **#40** — Local-first Drift/SQLite migration (schema should account for FSRS D/S/R fields)
6. **#41** — CRDT sync layer (depends on #40; FSRS state needs LWW-Register per field)
7. **#39** — Concept embeddings (#38 done; embedding similarity could predict confusion-based difficulty for FSRS)

### Learning Science Features (Issues #74–#78)
8. **#74** — Video-synchronized knowledge graph highlighting — nodes light up in sync with video playback, connected nodes glow with relationship explanations. Based on Mayer's signaling principle (g=0.38–0.53) and temporal contiguity (d=1.22)
9. **#75** — Cross-source semantic linking + expanded ingestion (podcasts, books) — embedding-based discovery of connections across sources, both at ingestion time and offline. Analogical encoding makes far transfer 3x more likely (Gentner et al., 2003). #38 done, depends on #39
10. **#76** — Elaborative interrogation (how/why deepening, d=0.56) + Ebbinghaus forgetting curve visualization — AI-guided Socratic follow-ups during quiz, plus visual sawtooth decay curves from FSRS retrievability. Depends on FSRS Phases 2-4
11. **#77** — Dual coding — combine verbal quiz items with visual representations (diagrams, graph snippets, icons). Mayer's multimedia principle: d=1.35–1.67. Knowledge graph already provides spatial/visual encoding; extend to per-concept visuals
12. **#78** — Interleaving — mix topics within quiz sessions instead of blocking by collection. Rohrer et al. (2020) classroom RCT: d=0.83, n=787. Random interleaving is a strong baseline. Metacognitive illusion: users prefer blocking, so default to interleaved
