# FSRS Migration: Closing the Extraction↔Scheduling Loop

## Origin Story

This insight emerged during a Feb 15 2026 session where we:
1. Ingested an 11-video Anthropic course on Agent Skills into Outline wiki
2. Created an `extracting-knowledge-graph` skill in `.claude/skills/` — encoding Engram's extraction workflow as a portable, progressively-disclosed skill
3. Noticed a comment in the skill: "SM-2 scheduling state is applied AFTER extraction because Claude has no knowledge of SM-2 when extracting"
4. Asked: **what if we used FSRS instead?**

That question broke open something fundamental.

## The SM-2 Wall

With SM-2, every new quiz card starts identically:
- `easeFactor: 2.5`
- `interval: 0`
- `repetitions: 0`

There is nothing Claude can contribute at extraction time because the initial state is a constant. The extraction service and the scheduling engine are **completely decoupled** — not by design choice, but because SM-2 provides no mechanism for coupling them.

The extraction service produces `(question, answer)`. The scheduler wraps it in `(question, answer, easeFactor=2.5, interval=0, repetitions=0)`. Claude's understanding of the content's difficulty, complexity, and pedagogical weight is discarded.

## FSRS Breaks the Wall

FSRS (Free Spaced Repetition Scheduler) operates on three memory variables:

- **Difficulty (D)**: Inherent complexity of the card (1-10). Affects how fast stability grows after review.
- **Stability (S)**: Time in days for retrievability to drop from 100% to 90%.
- **Retrievability (R)**: Probability of successful recall at a given moment.

The critical insight: **Difficulty is a property of the card, not the learner's history.**

In standard FSRS, initial difficulty is determined by the first rating: `D₀(G) = w₄ - (G-3) · w₅`. But Claude already has the information needed to predict that difficulty at extraction time:

- How many prerequisite concepts the answer depends on
- Whether the concept is abstract or concrete
- Whether the answer requires synthesis vs recall
- How information-dense the answer is
- How similar the concept is to commonly confused ones

### The Closed Loop

Instead of extracting `(question, answer)`, Claude extracts `(question, answer, predicted_difficulty)`.

```
BEFORE (SM-2):
  Extraction → (question, answer) → Fixed scheduling state
  Claude's understanding of difficulty: DISCARDED

AFTER (FSRS):
  Extraction → (question, answer, difficulty) → Informed scheduling state
  Claude's understanding of difficulty: PRESERVED AND USED
```

This means **the extraction skill we built teaches Claude not just how to extract knowledge, but how to predict how hard that knowledge is to learn.** The scheduler trusts those predictions. The loop is closed.

## Desired Retention by Graph Position

FSRS introduces `desired_retention` — the target probability of recall when a card is scheduled. This is a knob SM-2 doesn't have.

Combined with our dependency-aware knowledge graph, we can set desired retention per-concept based on structural importance:

| Graph Position | Desired Retention | Reasoning |
|---|---|---|
| **Hub concepts** (many dependents) | 0.95 | Forgetting a hub blocks many downstream concepts |
| **Standard concepts** | 0.90 | Default FSRS target |
| **Leaf concepts** (no dependents) | 0.85 | Lower stakes — nothing downstream is blocked |
| **Guardian-protected concepts** | 0.97 | Game mechanic: guardians ensure their cluster stays strong |
| **Repair mission targets** | Temporarily elevated | Currently 1.5x interval hack; `desired_retention` is more principled |

This replaces the crude `1.5x interval` multiplier for repair missions with a first-principles approach: instead of hacking the interval, tell the scheduler what retention level you actually want.

## Mean Reversion: Solving Ease Hell

SM-2's `easeFactor` can drop to 1.3 and stay there permanently — the infamous "ease hell" where cards get stuck in daily review cycles with no escape.

FSRS prevents this with mean reversion in the difficulty update:

```
D′(D,G) = w₇ · D₀(3) + (1 - w₇) · (D - w₆ · (G - 3))
```

This pulls difficulty toward a midpoint after each review. Even if Claude's initial difficulty prediction is wrong, FSRS self-corrects without trapping the learner.

## Impact on Extraction Quality

### Quiz Items That Are Too Easy (SM-2)
- Users always rate 5 → ease factor climbs → intervals grow fast → item barely reviewed
- **Problem**: Trivial questions don't build lasting knowledge
- **SM-2 response**: Nothing. The card just drifts away.

### Quiz Items That Are Too Easy (FSRS)
- Low initial difficulty + high ratings → stability grows naturally
- **FSRS response**: Card is scheduled further out, which is correct behavior
- **But**: If Claude predicted high difficulty and user rates it easy, mean reversion adjusts. Self-correcting.

### Quiz Items That Are Too Hard (SM-2)
- Users always rate 0-2 → ease factor drops to 1.3 → interval stuck at 1 day → frustrating
- **Problem**: "Ease hell" — no escape without manual intervention
- **User must**: Split into sub-concepts or reset the card manually

### Quiz Items That Are Too Hard (FSRS)
- High initial difficulty + low ratings → stability grows slowly but consistently
- **FSRS response**: Mean reversion prevents death spiral. The card adapts.
- **And**: Claude's predicted difficulty can trigger automatic sub-concept suggestions at extraction time: "This concept has predicted difficulty 9/10 — consider splitting"

## The Recursive Insight

This migration emerged from a session where we:
1. Ingested a course about agent skills into Outline
2. Built an extraction skill for Engram (a skill about how to extract knowledge)
3. Realized the skill could be improved by the scheduling algorithm it references
4. Discovered that FSRS closes a loop that SM-2 couldn't

**Engram is a tool that learns from wikis. We used it to ingest a course about skills. That course taught us to build a skill that makes Engram's extraction better. And the skill revealed that the scheduling algorithm should change — which in turn changes the skill itself.**

The tool is learning how to learn, and we're learning alongside it.

## Dart Package

[`fsrs` on pub.dev](https://pub.dev/packages/fsrs) — pure Dart, v2.0.1, 160/160 pub points, MIT license.

- 21 model weights (FSRS-6)
- Configurable `desired_retention` (0-1)
- Configurable learning steps
- No native dependencies — pure Dart

Alternative: [`fsrs-rs-dart`](https://github.com/open-spaced-repetition/fsrs-rs-dart) — Rust implementation with Flutter bindings via `flutter_rust_bridge`. Higher performance but adds native dependency.

**Recommendation**: Start with pure Dart `fsrs` package. Migrate to Rust bindings only if performance becomes an issue (unlikely for quiz scheduling).

## Migration Plan

### Phase 1: Add FSRS alongside SM-2 (non-breaking)

1. **Add `fsrs` package** to pubspec.yaml
2. **Add `difficulty` field to `QuizItem`** (nullable, defaults to null for existing cards)
3. **Update extraction tool schema** — add `predictedDifficulty` (1-10) to quiz item output
4. **Update extraction system prompt** — add difficulty prediction guidelines
5. **Update extraction skill** — rename `references/sm2-constraints.md` to `references/scheduling-constraints.md`, add FSRS content
6. **Write FSRS engine** — pure function mirroring SM-2 pattern, consuming `fsrs` package
7. **Tests**: Existing SM-2 tests continue passing; new FSRS tests for difficulty-informed scheduling

### Phase 2: Dual-mode scheduling

1. **Scheduler selects engine** based on card state:
   - Cards with `difficulty != null` → FSRS engine
   - Cards with `difficulty == null` (legacy) → SM-2 engine (or migrate with `difficulty = 5.0` default)
2. **Quiz screen rating**: SM-2 uses 0-5; FSRS uses Again/Hard/Good/Easy (4 grades). Need rating UI update.
3. **Desired retention provider** — computes per-concept retention based on graph position
4. **Update mastery visualization** — FSRS retrievability (0-1) maps more naturally to mastery colors than SM-2's binary "mastered/not" heuristic

### Phase 3: Full FSRS (deprecate SM-2)

1. **Migrate all legacy cards** — set `difficulty = 5.0` (neutral midpoint), convert SM-2 state to FSRS state
2. **Remove SM-2 engine** and related code
3. **Update cooperative game mechanics** — replace `1.5x interval` hack with `desired_retention` adjustments
4. **Update challenge quiz item snapshots** — strip FSRS scheduling fields (same security concern as #30)

### Phase 4: Extraction-informed scheduling (the closed loop)

1. **Claude predicts difficulty at extraction time** — added to tool schema in Phase 1, now used by scheduler
2. **Difficulty prediction evaluation** — compare Claude's predicted D₀ with actual D after 5+ reviews per card
3. **Feedback loop** — if predictions are consistently off, adjust extraction prompt (or retrain with review data)
4. **Auto sub-concept suggestion** — if predicted difficulty > 8, suggest splitting at extraction time

## Interactions with Other Planned Work

| Feature | Impact |
|---|---|
| **#38 Typed relationships** | Relationship types inform difficulty prediction — "depends on" chains increase predicted difficulty |
| **#39 Concept embeddings** | Embedding similarity could predict confusion-based difficulty (similar concepts = harder to distinguish) |
| **#40 Local-first Drift/SQLite** | FSRS state is more complex than SM-2 — schema design should account for D, S, R fields |
| **#41 CRDT sync** | FSRS card state (D, S, R) needs CRDT treatment — LWW-Register per field with `lastReview` as timestamp |
| **Guardian system** | `desired_retention` per cluster replaces crude interval multipliers |
| **Network health** | Retrievability (R) is a better input to `NetworkHealthScorer` than SM-2's binary mastery |

## Decision

**Migrate from SM-2 to FSRS.** The closed extraction↔scheduling loop is the primary motivation, but ease-hell prevention, per-concept desired retention, and principled game mechanic integration are strong secondary reasons. The pure Dart `fsrs` package makes this a clean replacement.

## References

- [FSRS Algorithm](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm)
- [ABC of FSRS](https://github.com/open-spaced-repetition/fsrs4anki/wiki/abc-of-fsrs)
- [dart-fsrs package](https://pub.dev/packages/fsrs)
- [FSRS GitHub](https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler)
- [Anthropic Agent Skills course](https://kb.xdeca.com/collection/agent-skills-with-anthropic-3wNTu43J6m) — ingested into Outline, catalyst for this investigation
