# Local-First Architecture

> Decision: **Migrate to local-first with Drift/SQLite as primary storage, Firestore as sync peer.** The personal knowledge atlas should live on the device first, sync to the cloud for backup and collaboration.

## Motivation

Engram has two souls:

1. **Personal knowledge atlas** — SM-2 scheduling, spaced repetition, knowledge graph, sub-concept mastery, cross-discipline semantic relationships. Inherently personal and offline-friendly.
2. **Cooperative team game** — guardians, glory board, challenges, nudges, repair missions. Inherently networked.

The current architecture (Firestore-primary, local JSON fallback) optimizes for soul #2 at the expense of soul #1. Local-first inverts this: the device is the primary read/write path, the server handles sync, compute, and social coordination.

## What Local-First Means (And Doesn't Mean)

Local-first does **not** mean server-less. It means:

- **Local storage is the primary read/write path** — no spinners, no network in the hot path
- **The app works fully offline** for personal features (quiz review, sub-concept splitting, knowledge graph)
- **A server exists** for sync, backup, Claude API calls, and social feature coordination
- **Changes sync via CRDTs** for conflict-free multi-device and multi-user merging (see `CRDT_SYNC_ARCHITECTURE.md`)

## Current Architecture vs Proposed

### Current (Firestore-Primary)

```
User action → Riverpod provider → Firestore write (network) → Local state update
                                        ↓
                                  Other devices (real-time)
```

- Quiz review requires network write (~200ms)
- Offline mode is degraded (JSON fallback, no social features)
- Every quiz review costs a Firestore write

### Proposed (Local-Primary + Server Sync)

```
User action → Riverpod provider → Drift/SQLite write (<1ms) → UI update
                                        ↓ (background)
                                  CRDT sync → Server → Other devices
```

- Quiz review is instant (local write)
- Full offline experience for personal learning
- Social features gracefully degrade offline, fully functional online
- Server handles Claude API, friend discovery, challenge routing

## What the Server Still Does

The server is not diminished — its role is **clarified**:

| Server Role | What It Does | Why It Needs a Server |
|-------------|-------------|----------------------|
| **Compute node** | Claude API for concept extraction + embeddings | API keys, rate limits, heavy compute |
| **Sync peer** | Receives CRDT operations, merges, fans out | Durable storage, always-on availability |
| **Social hub** | Friend discovery, challenge/nudge routing | Needs central index to match wiki URLs |
| **Backup** | Durable storage of merged CRDT state | Device loss recovery |
| **Aggregation** | Glory board rankings, team health (optional) | Can also be computed client-side |

## Benefits

### For Personal Learning
- **Instant quiz reviews** — no network latency in the learning loop
- **Full offline capability** — review on planes, in tunnels, during outages
- **Sub-concept splitting is frictionless** — restructure your graph freely, sync later
- **Embeddings work offline** — Claude computes them at extraction time, stored locally forever

### For the Product
- **Privacy by default** — user data stays on device unless team features are enabled
- **Lower costs** — no Firestore read/write charges for personal operations
- **Resilience** — Firestore outage doesn't break the core experience
- **No vendor lock-in** — local SQLite is portable; sync backend can be swapped

### For Cooperative Features
- **Social features work exactly like now** when online (server mediates)
- **Guardian points, goal contributions, glory** sync via CRDTs (naturally additive)
- **Offline operations queue** and sync when connectivity returns

## Costs and Risks

### Migration Effort
- Implementing Drift/SQLite tables to mirror the existing Firestore schema
- Adding HLC timestamps for CRDT ordering
- Building the sync layer (or adopting `sqlite_crdt` + `crdt_sync`)
- Dual-running period where both storage paths coexist
- Testing sync edge cases (offline for weeks, large deltas)

### What It Does NOT Cost
- **Rewriting providers** — Riverpod still manages UI state; reads come from Drift instead of Firestore
- **Losing social features** — server stays; social features route through it
- **Changing the data model** — concepts, relationships, quiz items stay the same
- **Claude API changes** — extraction still hits the server

### Risks
- **Sync conflicts** — mitigated by CRDT design (see `CRDT_SYNC_ARCHITECTURE.md`)
- **Data loss on device** — mitigated by server backup
- **Complexity** — more moving parts than Firestore-only, but each part is simpler

## Database Choice: Drift/SQLite

### Why Drift

- **Already normalized** — Firestore already stores concepts, relationships, quiz items in separate subcollections. Drift tables mirror this exactly.
- **Reactive queries** — `watch()` returns streams, giving fine-grained UI rebuilds for free
- **Graph traversal** — recursive CTEs for shortest path, dependency chains
- **FTS5** — full-text search across concept descriptions
- **Battle-tested** — cross-platform, actively maintained, type-safe
- **CRDT-compatible** — `sqlite_crdt` package provides HLC timestamps and automatic merge

### Schema (Mirrors Firestore)

```sql
CREATE TABLE concepts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  source_document_id TEXT NOT NULL,
  hlc TEXT NOT NULL  -- Hybrid Logical Clock for CRDT
);

CREATE TABLE relationships (
  id TEXT PRIMARY KEY,
  from_concept_id TEXT REFERENCES concepts(id),
  to_concept_id TEXT REFERENCES concepts(id),
  label TEXT NOT NULL,
  hlc TEXT NOT NULL
);

CREATE TABLE quiz_items (
  id TEXT PRIMARY KEY,
  concept_id TEXT REFERENCES concepts(id),
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  ease_factor REAL NOT NULL DEFAULT 2.5,
  interval INTEGER NOT NULL DEFAULT 0,
  repetitions INTEGER NOT NULL DEFAULT 0,
  next_review TEXT,
  last_review TEXT,
  hlc TEXT NOT NULL
);
```

### Migration Path

The existing `GraphStore` interface already abstracts storage. The migration can be incremental:

1. Add Drift as a parallel storage backend (dual-write with Firestore)
2. Switch reads to Drift-primary (Firestore becomes write-through sync)
3. Add CRDT sync layer for multi-device consistency
4. Make Firestore sync optional (personal-only mode works without it)

## Interaction with Other Decisions

- **Graph state management** (`GRAPH_STATE_MANAGEMENT.md`): Drift's reactive queries provide per-entity granularity naturally, reducing the need for manual Riverpod `family` provider splitting.
- **CRDT sync** (`CRDT_SYNC_ARCHITECTURE.md`): Local-first requires CRDTs for conflict-free sync. The knowledge graph's additive nature makes this clean.
- **Sub-concept splitting**: Local-first makes this frictionless — split, experiment, restructure without network round-trips.
- **Embeddings**: Computed by Claude at extraction (online), stored locally, queried offline forever.

## References

- Ink & Switch: "Local-First Software" (Martin Kleppmann et al.) — the foundational paper
- `sqlite_crdt` (Daniel Cachapa) — SQLite with built-in CRDT support for Dart
- `crdt_sync` — sync protocol companion to `sqlite_crdt`
- PowerSync — commercial local-first sync for Flutter (SQLite + Postgres)
- Drift documentation — reactive SQLite for Dart
