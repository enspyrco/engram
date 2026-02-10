# CRDT Sync Architecture

> Decision: **Use CRDTs with Hybrid Logical Clocks for conflict-free sync between local-first devices and the server.** The knowledge graph's additive nature maps naturally to CRDT types. The server remains a sync peer, compute node, and social hub.

## Why CRDTs

In a local-first architecture, multiple replicas (phone, laptop, server) can modify the knowledge graph independently. When they reconnect, changes must merge without conflicts. CRDTs (Conflict-Free Replicated Data Types) guarantee that replicas converge to the same state regardless of the order operations are received.

The key insight: **Engram's knowledge graph operations are overwhelmingly additive**, which is the ideal case for CRDTs.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Device A (phone)                               │
│  ┌───────────┐  ┌────────────────────────────┐  │
│  │ Drift/SQL │←→│ CRDT merge layer (HLC)     │──┼──┐
│  │ (local)   │  │ sqlite_crdt / custom       │  │  │
│  └───────────┘  └────────────────────────────┘  │  │
└─────────────────────────────────────────────────┘  │
                                                      │ background sync
┌─────────────────────────────────────────────────┐  │
│  Device B (laptop)                              │  │
│  ┌───────────┐  ┌────────────────────────────┐  │  │
│  │ Drift/SQL │←→│ CRDT merge layer (HLC)     │──┼──┤
│  │ (local)   │  │ sqlite_crdt / custom       │  │  │
│  └───────────┘  └────────────────────────────┘  │  │
└─────────────────────────────────────────────────┘  │
                                                      │
┌─────────────────────────────────────────────────┐  │
│  Server (Firestore or Postgres)                 │  │
│  ┌───────────┐  ┌───────────┐  ┌─────────────┐ │  │
│  │ Merged    │←─│ Sync      │←─│ CRDT merge  │←┼──┘
│  │ state     │  │ protocol  │  │ (server)    │ │
│  └───────────┘  └───────────┘  └─────────────┘ │
│  ┌───────────┐  ┌───────────┐                   │
│  │ Claude API│  │ Social    │                   │
│  │ (compute) │  │ routing   │                   │
│  └───────────┘  └───────────┘                   │
└─────────────────────────────────────────────────┘
```

## CRDT Type Mapping

### Personal Learning Data

| Data | CRDT Type | Merge Strategy | Rationale |
|------|-----------|---------------|-----------|
| Concepts | G-Set (grow-only) | Union | Concepts are added, rarely deleted. Two devices adding different concepts merge cleanly. |
| Relationships | G-Set | Union | Additive. Two devices creating different relationships merge cleanly. |
| Quiz Items | G-Set + LWW-Register | Union for creation, last-write-wins for scheduling fields | New items merge by union. Scheduling state (easeFactor, interval, etc.) uses the most recent review timestamp. |
| Sub-concept splits | G-Set | Union | Splitting creates new concepts + relationships — purely additive. |
| Document metadata | G-Set | Union | Ingested documents are append-only. |
| Concept embeddings | LWW-Register per concept | Latest extraction wins | Embeddings are recomputed on re-extraction; latest version is correct. |

### Cooperative Features

| Data | CRDT Type | Merge Strategy | Rationale |
|------|-----------|---------------|-----------|
| Guardian assignments | LWW-Register per cluster | Last volunteer wins | Single-writer per cluster. Server can arbitrate ties. |
| Glory points | G-Counter per category per user | Max per replica | Points only increment. Merge by taking max per counter ID. |
| Team goal contributions | G-Counter per user per goal | Max per replica | Contributions only accumulate. Naturally convergent. |
| Team goals | G-Set + LWW-Register | Union for creation, LWW for status | Goals are created (additive) and completed (LWW on completedAt). |
| Catastrophe events | G-Set | Union | Events are created, never removed from history. |
| Repair missions | G-Set (reviewed concepts) | Union | Reviewing a concept is additive. Mission completes when set is full. |
| Challenges/Nudges | G-Set | Union, ordered by HLC timestamp | Messages are append-only. |

### Why This Works So Well

The cooperative game features designed in Phases 1-4 are **accidentally CRDT-native**:

- Glory points only increment (G-Counter)
- Goal contributions only accumulate (G-Counter)
- Guardian assignments are single-writer per cluster (LWW-Register)
- Catastrophe events and repair missions are append-only (G-Set)
- Challenge/nudge messages are append-only (G-Set)

No feature requires multi-writer conflict resolution on the same field. The hardest operation — sub-concept splitting — is purely additive (creates new entities).

## Hybrid Logical Clocks (HLC)

Each row in the local database carries an HLC timestamp for causal ordering. HLC combines a physical clock with a logical counter to guarantee:

1. **Monotonicity**: timestamps always increase, even with clock skew
2. **Causality**: if operation A caused operation B, `hlc(A) < hlc(B)`
3. **Uniqueness**: no two operations share a timestamp (counter disambiguates)

```dart
// Conceptual HLC structure
class HLC {
  final int wallClockMs;  // Physical time
  final int counter;      // Logical counter for same-ms events
  final String nodeId;    // Device identifier
}
```

The `sqlite_crdt` package implements HLC natively, attaching timestamps to every row modification.

## Sync Protocol

### Changeset Exchange

Devices exchange changesets — sets of (row, HLC timestamp) pairs. The merge rule is simple: for each row, keep the version with the highest HLC.

```
Device A offline for 3 days:
  - Reviewed quiz items q1, q5, q12 (LWW-Register updates)
  - Split concept c3 into c3a, c3b, c3c (G-Set additions)
  - Earned 5 guardian points (G-Counter increment)

Reconnects:
  1. Send changeset to server: {q1@hlc7, q5@hlc8, q12@hlc9, c3a@hlc10, ...}
  2. Server merges with its state (other devices may have synced too)
  3. Server sends back any changes Device A hasn't seen
  4. Device A merges incoming changes
  5. Both replicas converge
```

### Server as Sync Peer

The server is just another replica in the CRDT system. It:

1. **Receives** changesets from devices
2. **Merges** them into its own state (same CRDT rules)
3. **Forwards** merged changesets to other devices
4. **Persists** the merged state durably (Firestore or Postgres)

For social features specifically, the server also:

5. **Routes** challenges/nudges between users (these cross user boundaries)
6. **Indexes** wiki group membership for friend discovery
7. **Runs** Claude API calls and pushes results as CRDT additions

## Edge Cases

### Quiz Item Reviewed on Two Devices Simultaneously

User reviews quiz item `q1` on phone (rating: 4) and laptop (rating: 2) before syncing.

- Phone: `q1.easeFactor = 2.6, interval = 10, lastReview = hlc_phone_5pm`
- Laptop: `q1.easeFactor = 2.18, interval = 1, lastReview = hlc_laptop_5:01pm`

LWW-Register resolves: laptop's HLC is later, so laptop's scheduling state wins. This is correct — the most recent review should determine the scheduling state.

### Sub-Concept Split on One Device, Relationship Added on Another

Device A splits concept "Observability" into 3 sub-concepts. Device B adds a relationship from "Observability" to "SRE."

After sync:
- All 3 sub-concepts exist (G-Set union)
- The "Observability" → "SRE" relationship exists (G-Set union)
- The relationship points to the original concept, which still exists as the parent
- No conflict — both operations were additive

### Concept Deletion (Rare)

If deletion is needed, use **tombstones** (mark as deleted with HLC, don't physically remove). Other devices see the tombstone and hide the concept. If a device creates a relationship to a tombstoned concept before seeing the tombstone, the relationship survives (points to a hidden concept) — which can be cleaned up on the next sync.

In practice, concept deletion should be rare. Sub-concept splitting is additive (parent stays, children added). Incorrect extractions can be tombstoned.

### Long Offline Period

User is offline for 3 weeks, reviews 200 quiz items. Reconnects.

- Changeset is ~200 LWW-Register updates + any structural changes
- Server merges in O(n) where n = changeset size
- Server sends back 3 weeks of other users' changes
- All merges are deterministic — no user intervention needed

## Implementation Options

### Option A: `sqlite_crdt` + `crdt_sync` (Recommended)

Daniel Cachapa's `sqlite_crdt` package provides:
- SQLite tables with automatic HLC timestamps
- Changeset generation (`getChangeset(since: lastSync)`)
- Merge function (`merge(changeset)`)
- Built on top of `sqflite` (compatible with Drift via raw queries)

The `crdt_sync` companion handles the transport layer.

**Pros**: Purpose-built for this use case, proven in production, Dart-native.
**Cons**: May need adaptation to work cleanly with Drift's type-safe query builder.

### Option B: Custom CRDT Layer on Drift

Build a thin CRDT layer on top of Drift tables:
- Add `hlc TEXT` column to every table
- Implement `Changeset` class for delta sync
- Implement merge logic per CRDT type (G-Set = INSERT OR IGNORE, LWW = INSERT OR REPLACE WHERE hlc > existing)

**Pros**: Full control, tight Drift integration, no additional dependency.
**Cons**: More implementation work, need to get merge semantics right.

### Option C: PowerSync (Commercial)

PowerSync provides a complete local-first sync layer for Flutter:
- Local SQLite database
- Syncs with Postgres backend
- Handles conflict resolution
- Dashboard for monitoring

**Pros**: Batteries-included, production-grade.
**Cons**: Requires migrating from Firestore to Postgres, commercial dependency, less control.

## Migration Strategy

### Phase 1: Dual-Write Foundation

- Add Drift/SQLite as a parallel storage backend
- Write to both Drift and Firestore on every operation
- Read from Drift (local-primary)
- Verify consistency between both stores

### Phase 2: CRDT Timestamps

- Add HLC columns to all Drift tables
- Start recording timestamps on every write
- Build changeset generation (`getChangeset(since: hlc)`)

### Phase 3: Sync Layer

- Implement merge logic (per CRDT type mapping above)
- Build background sync service (push changesets to server, pull from server)
- Server-side merge in Firestore (or migrate to Postgres)

### Phase 4: Firestore Optional

- Personal features work entirely offline with Drift
- Firestore (or replacement) used only for social sync + backup
- New users can use the app without Firebase account for personal learning

## References

- Ink & Switch: "Local-First Software" — foundational paper on the philosophy
- Martin Kleppmann: "Designing Data-Intensive Applications" — CRDT theory (Chapter 5)
- `sqlite_crdt` (Daniel Cachapa): pub.dev/packages/sqlite_crdt
- `crdt_sync`: pub.dev/packages/crdt_sync
- `crdt` (base package): pub.dev/packages/crdt
- Hybrid Logical Clocks: "Logical Physical Clocks" (Kulkarni et al., 2014)
- PowerSync: powersync.com — commercial local-first for Flutter
