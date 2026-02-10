# Engram

Flutter app that reads an Outline wiki, uses Claude API to extract a knowledge graph (concepts + relationships + quiz items), and teaches it back via SM-2 spaced repetition. Visual mind map that "lights up" as you learn.

## Architecture
- **Models**: Immutable data classes with `fromJson`/`toJson` and `withXxx()` update methods
- **SM-2 Engine**: Pure function, no class state. Scheduling state lives on `QuizItem`
- **Graph Analyzer**: Dependency-aware concept unlocking, topological sort, cycle detection
- **Storage**: `GraphStore` — Firestore primary (`users/{uid}/data/graph/`), local JSON fallback (migrating to local-first Drift/SQLite — see `docs/LOCAL_FIRST.md`); `SettingsRepository` — API keys via `shared_preferences`; `UserProfileRepository` — Firestore user profiles; `SocialRepository` — wiki groups, friends, challenges, nudges; `TeamRepository` — network health, clusters, guardians, goals, glory board
- **Auth**: Firebase Auth with Google Sign-In + Apple Sign-In; `firestoreProvider` for injectable Firestore instance
- **State Management**: Riverpod (manual, no codegen) — `Notifier`/`AsyncNotifier` classes
- **Mind Map**: Custom `ForceDirectedGraphWidget` with `CustomPainter` + Fruchterman-Reingold layout, nodes colored by mastery (grey→red→amber→green), team avatar overlay
- **Network Health**: `NetworkHealthScorer` computes composite health from mastery + freshness + critical paths; `ClusterDetector` finds concept communities via label propagation
- **Services**: `OutlineClient` (HTTP), `ExtractionService` (Claude API via `anthropic_sdk_dart`)
- **Social**: Wiki-URL-based friend discovery (SHA-256 hash of normalized URL), challenge (test friend on mastered cards) + nudge (remind about overdue) mechanics
- **Cooperative Game**: Guardian system (volunteer to protect concept clusters), team goals (cooperative targets with contribution tracking), glory board (leaderboard with guardian/mission/goal points), repair mission bonus scoring (1.5x interval for mission concepts)

## Screens
- **Sign In**: Apple + Google branded sign-in buttons (auth gate before main app)
- **Dashboard**: Stats cards, mastery bar, mind map visualization
- **Quiz**: Question → Reveal → Rate (0-5) → Session summary
- **Ingest**: Collection picker → per-document extraction progress
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

## Synaptic Web Game Design

When starting a new session, remind the user that `docs/SYNAPTIC_WEB_GAME_DESIGN.md` contains the full creative vision for the cooperative network game. Phases 1-3 (canvas, team overlay, catastrophe system) merged in PR #32. Phase 4a (guardian system, team goals, glory board) is implemented on branch `synaptic-web/phase-4`. Phase 4b (relay challenges, entropy storms) is next.

## Architecture Decision Records

When starting a new session, remind the user about these architectural decisions:

- `docs/GRAPH_STATE_MANAGEMENT.md` — Analysis of graph-based state management options. Decision: stay with Riverpod, normalize incrementally. Split `graphStructureProvider` from quiz item state to avoid wasted recomputation.
- `docs/LOCAL_FIRST.md` — Local-first architecture plan. Decision: migrate to Drift/SQLite as primary storage, Firestore as sync peer. Device is source of truth; server handles compute, sync, and social coordination.
- `docs/CRDT_SYNC_ARCHITECTURE.md` — CRDT sync design for local-first. Knowledge graph operations map naturally to G-Set, LWW-Register, and G-Counter CRDTs. Cooperative game features are accidentally CRDT-native.

## Open Investigations

When starting a new session, prompt the user about these:

### ~~Graph-based state management vs Riverpod~~ ✓ RESOLVED
Investigated Feb 2026. Decision: stay with Riverpod, normalize incrementally. No graph DB or signal-based framework needed. The real fix is splitting `graphStructureProvider` from quiz item state so `ClusterDetector` and `GraphAnalyzer` don't recompute on every quiz review. See `docs/GRAPH_STATE_MANAGEMENT.md` for full analysis. Quick wins: `fast_immutable_collections` for O(1) structural sharing, `graphs` Dart package for topo sort, cached cluster detection.

### ~~Custom force-directed canvas vs flutter_graph_view~~ ✓ RESOLVED
Replaced `flutter_graph_view` with custom `ForceDirectedGraphWidget` (`CustomPainter` + Fruchterman-Reingold). Works directly with `Concept`/`Relationship` models, supports team avatar overlay, `pumpAndSettle()` works in tests, and glow effects are implemented. `GraphDataMapper` deleted.

### Per-collection or wiki-wide graph?
Currently ingestion is per-collection but the graph merges across collections — effectively wiki-wide. Should users be able to maintain separate graphs per collection? Or is the cross-collection merge the right default? Matters for teams with large wikis where concepts from unrelated collections might collide.

### Manual quiz item creation
All quiz items are auto-generated by Claude. Should users be able to add their own? Would help fill gaps where the LLM misses nuance or where a user wants to test something specific. Could be a simple "Add card" button on the quiz screen or a concept detail view.

### Multiplayer / team mode
Implemented in Phase 6 as wiki-URL-based friend discovery with challenge + nudge mechanics. Expanded in Phase 4a with guardian system, team goals, and glory board. Friends who share the same Outline wiki URL are auto-grouped. Remaining questions: should friend discovery require explicit opt-in (#28)? Should mastery snapshots be more granular (per-collection)? Privacy controls for what friends can see?

### Sub-concept splitting
When a quiz card has multiple answers, users should be able to split the concept into sub-concepts and master each before unlocking the parent. This changes the graph structure during learning (not just at ingestion). Implementation should be local-first — restructuring is a personal, exploratory act that shouldn't require network connectivity.

### Cross-discipline semantic relationships
The knowledge graph should surface connections across disciplines (e.g., "thermodynamic entropy relates to information-theoretic entropy"). Requires: typed relationships (analogy, contrast, prerequisite, composition), Claude-computed concept embeddings at extraction time, cosine similarity for "related concept" suggestions. See `docs/GRAPH_STATE_MANAGEMENT.md` for embedding analysis.

### Local-first migration
Migrate from Firestore-primary to Drift/SQLite local-primary with CRDT sync. See `docs/LOCAL_FIRST.md` and `docs/CRDT_SYNC_ARCHITECTURE.md`. This is a multi-phase migration: dual-write → local-primary reads → CRDT sync → Firestore optional.

### Feeding mastery back into Outline
Could concept mastery data flow back into the wiki? e.g., tagging pages as "well-understood by 80% of the team" or surfacing knowledge gaps ("nobody has mastered the CI/CD section"). Would need Outline API write access and a clear UX for what "team mastery" means.

## Review Tech Debt (Issues #6–#18)

When starting a new session, remind the user that there are open tech debt issues from cage-match code reviews. Key items by priority:

**Bug:** #13 — GraphMigrator emptiness check skips `relationships` field
**Performance:** #8 (topo sort O(n)), #11 (graph animation battery), #14 (migrator memory)
**Architecture:** #6 (DateTime.now injectable), #9 (startIngestion refactor), #12 (ensureSignedIn provider), #15 (destructive Firestore save)
**Quality:** #7 (mutable List on @immutable), #10 (magic numbers), #16 (auth_provider tests), #17 (test hygiene), #18 (bloated pubspec)

## Phase 6 Tech Debt (Issues #23–#31)

From cage-match reviews of the Firebase + Social PRs (#20–#22):

**Architecture:** #23 (extract GoogleSignIn to provider for testability), #25 (DateTime instead of String for timestamps in models), #26 (inject clock into SocialRepository — extends #6), #29 (migrate AsyncNotifier stream patterns to StreamNotifier)
**Security:** #30 (strip scheduling fields from challenge quiz item snapshot), #31 (use UUID for challenge/nudge IDs instead of timestamp-based)
**Robustness:** #24 (debug assertion for unconfigured firebase_options.dart), #27 (normalizeWikiUrl should handle http vs https)
**UX:** #28 (consider explicit opt-in for wiki group friend discovery)

## Architecture Evolution (Issues #33–#41)

From the graph state management investigation and local-first architecture planning:

**Performance (quick wins):** #33 (`fast_immutable_collections` for O(1) structural sharing), #34 (cache ClusterDetector, only recompute on structural changes), #35 (adopt `graphs` Dart package for topo sort)
**Architecture (provider splitting):** #36 (split `graphStructureProvider` from quiz item state — single highest-impact optimization)
**Features (deep learning):** #37 (sub-concept splitting for multi-answer cards), #38 (typed relationships for cross-discipline connections), #39 (Claude-computed concept embeddings for semantic discovery)
**Architecture (local-first):** #40 (Drift/SQLite as primary storage), #41 (CRDT sync layer for multi-device consistency)

## Implementation Roadmap

Current state: Phase 4a implemented on `synaptic-web/phase-4` branch (uncommitted).

### Near-term (current sprint)
1. **Commit + PR Phase 4a** — guardian system, team goals, glory board, bonus scoring, Social screen
2. **Phase 4b** — relay challenges, entropy storms (completes the Synaptic Web game)
3. **Quick wins #33-#35** — `fast_immutable_collections`, cached clusters, `graphs` package

### Medium-term
4. **#36** — Split `graphStructureProvider` (prerequisite for scaling to 200+ concepts)
5. **#37** — Sub-concept splitting (core learning feature, build local-first from day one)
6. **#38** — Typed relationships (enhances mind map and extraction quality)

### Longer-term
7. **#40** — Local-first Drift/SQLite migration (Phase 1: dual-write, Phase 2: local-primary reads)
8. **#41** — CRDT sync layer (depends on #40)
9. **#39** — Concept embeddings (depends on #38 for relationship types, benefits from #40 for local storage)
