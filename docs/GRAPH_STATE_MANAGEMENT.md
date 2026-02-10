# Graph-Based State Management Analysis

> Decision: **Stay with Riverpod, normalize incrementally.** No graph database or graph-reactive framework needed at current scale. The real fix is splitting derived providers to avoid wasted recomputation.

## Status: RESOLVED

Investigated February 2026. This was an open investigation in CLAUDE.md since early development. The conclusion is to pursue phased normalization within Riverpod, not a paradigm shift.

## Context

Engram stores the entire `KnowledgeGraph` as a single immutable blob in one `AsyncNotifierProvider`. Updating one quiz item replaces the whole graph and rebuilds all watchers. The graph has: Concepts (nodes), Relationships (edges), QuizItems (attached to concepts), plus overlay data like clusters, guardians, mastery states, health scores.

Current scale: 20-100 concepts per user. Target: 500+. Future: potentially 1000+ with sub-concept splitting.

## Options Evaluated

### Embedded Graph Databases (Rejected)

No production-ready embedded graph database exists for Dart/Flutter:

- **flutter_graph_database** (Rody Davis): Proof-of-concept using SQLite + Drift with recursive CTEs for traversal. Demonstrates the pattern works but not a maintained library.
- **ObjectBox**: Supports `ToOne`/`ToMany` relations and on-device HNSW vector search (v4.0), but no graph traversal primitives. Object-relational, not a true graph DB.
- **Isar**: Supports links between collections but link queries are expensive. Development appears stalled.
- **Drift/SQLite**: The strongest option if a local graph store were needed. Supports recursive CTEs, FTS5, reactive `watch()` queries. The `simple-graph` pattern (nodes + edges tables) is proven at several thousand nodes.

**Verdict**: At 100-500 nodes, in-memory structures are faster and simpler than any database. If local persistence is needed (see `LOCAL_FIRST.md`), Drift/SQLite is the path.

### Graph-Reactive State Management (Rejected for Now)

- **Signals for Dart** (`signals` package, 8.2k weekly downloads): Based on Preact Signals. Automatic dependency tracking — computed signals only recompute when specific dependencies change. Conceptually ideal (each concept/quiz item as a signal) but a full paradigm shift from Riverpod.
- **MobX for Dart**: Transparent Functional Reactive Programming. `Observable`, `Computed`, `Reaction` primitives. Well-suited for mutable graph structures but requires rewriting all providers.
- **Jotai-style atoms**: Each piece of state is an atom; atoms derive from other atoms. Maps naturally to a knowledge graph but no mature Dart implementation.

**Verdict**: The gains don't justify migrating away from Riverpod. The same granularity can be achieved with Riverpod `family` providers.

### Entity-Component-System (Rejected)

ECS maps naturally to a knowledge graph (Entity = concept, Components = mastery/scheduling/cluster data, Systems = SM-2/health/catastrophe). But Dart ECS packages (`flutter_event_component_system`, `entitas`) are immature, and the paradigm is unfamiliar to Flutter developers.

### Normalized State Store (Recommended)

The Redux community's normalization pattern — flat maps of entities keyed by ID — is the most incremental path. Riverpod `family` providers achieve the same granularity:

```dart
final quizItemProvider = Provider.family<QuizItem?, String>((ref, id) {
  final items = ref.watch(quizItemsMapProvider);
  return items[id];
});
```

## The Actual Problem

The bottleneck isn't the state management paradigm. It's **wasted recomputation of derived state**.

### Blast Radius of a Quiz Item Review

When `rateItem()` updates a single quiz item:

1. `withUpdatedQuizItem()` creates a new `KnowledgeGraph` (O(n) list copy, but only quizItems — concepts/relationships are reference-reused)
2. **13 watchers** fire, including:
   - `networkHealthProvider` — runs `NetworkHealthScorer.score()` which instantiates `GraphAnalyzer` (O(E)), classifies all concepts (O(n)), runs `ClusterDetector` (O(50n))
   - `graphAnalysisProvider` — reinstantiates `GraphAnalyzer` (redundant)
   - `dashboardStatsProvider` — recounts all quiz items + cascades from graphAnalysis
   - 2 UI screens rebuild

### The Key Finding

`graphAnalysisProvider` and `ClusterDetector` depend on **graph structure** (concepts + relationships), which **doesn't change** when a quiz item's scheduling state changes. They recompute unnecessarily on every quiz review.

### Performance by Scale

| Concepts | Quiz Items | Time per review | User experience |
|----------|-----------|----------------|-----------------|
| 100 | ~300 | ~10-20ms | Imperceptible |
| 300 | ~900 | ~30-60ms | Marginal on old devices |
| 500 | ~1500 | ~50-150ms | Potential jank |
| 1000+ | ~3000+ | ~200-500ms | Clearly problematic |

## Recommended Approach (Phased)

### Phase A: Quick Wins (No Architecture Change)

1. **`fast_immutable_collections`** — Switch `List<Concept>` etc. to `IList` for O(1) structural sharing in `withUpdatedQuizItem()`.
2. **Cache ClusterDetector results** — Clusters only change when concepts/relationships change (ingestion), not on quiz review. Memoize.
3. **Adopt the `graphs` Dart package** (by the Dart team) — Replace hand-rolled topological sort with battle-tested `topologicalSort()` and `shortestPath()`.

### Phase B: Selective Provider Splitting (200+ Concepts)

4. **Split `graphStructureProvider`** from quiz item state:

```dart
final graphStructureProvider = Provider<_GraphStructure?>((ref) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null) return null;
  return _GraphStructure(graph.concepts, graph.relationships);
});

final graphAnalysisProvider = Provider<GraphAnalyzer?>((ref) {
  final structure = ref.watch(graphStructureProvider);
  if (structure == null) return null;
  return GraphAnalyzer(structure);
});
```

This stops quiz reviews from triggering graph analysis, cluster detection, and topo sort.

5. **Riverpod `family` providers** for per-entity access where needed.

### Phase C: If 1000+ Concepts

6. Drift/SQLite as local persistence with reactive queries (see `LOCAL_FIRST.md`)
7. ObjectBox vector search if semantic similarity features are added

## What NOT to Do

- Do not adopt MobX (paradigm shift, smaller community)
- Do not adopt ECS (immature Dart packages)
- Do not build a graph database (overkill for 500 nodes)
- Do not compute graph embeddings on-device now (defer to Claude API at extraction time)

## References

- `graphs` package (Dart team): `shortestPath`, `topologicalSort`, `stronglyConnectedComponents`
- `directed_graph` package: richer API with `GraphCrawler`
- `fast_immutable_collections`: O(1) structural sharing for immutable collections
- `signals` package (Rody Davis): signal-based reactive primitives for Dart
- Rody Davis: "How to build a graph database with Flutter" (SQLite + Drift pattern)
- `simple-graph` (Python/SQLite): proven at several thousand nodes
- Redux normalization docs: `redux.js.org/usage/structuring-reducers/normalizing-state-shape`

## Real-World Precedents

- **Anki**: Normalized SQLite, no graph DB, handles millions of cards
- **Obsidian**: In-memory index, surgical re-indexing on edit
- **Roam Research**: Uses Datascript (Datalog graph DB) — but Roam's core UX *is* graph traversal; Engram's core UX is quiz review
- **RemNote**: Cloud-synced with spaced repetition; knowledge graph is visualization, not core data structure
