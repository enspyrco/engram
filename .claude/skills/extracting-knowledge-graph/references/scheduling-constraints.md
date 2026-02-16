# Scheduling Constraints (FSRS + SM-2 Legacy)

## The Closed Loop: Extraction Informs Scheduling

Unlike SM-2 (where scheduling state is applied AFTER extraction with no extraction-time input), **FSRS allows Claude to predict quiz item difficulty at extraction time**. This predicted difficulty becomes the initial D₀ for FSRS scheduling.

```
SM-2:  extraction → (question, answer) → fixed easeFactor=2.5  [DECOUPLED]
FSRS:  extraction → (question, answer, difficulty) → informed D₀  [CLOSED LOOP]
```

## FSRS Core Variables

| Variable | Meaning | Range |
|---|---|---|
| **Difficulty (D)** | Inherent complexity of the card | 1-10 |
| **Stability (S)** | Days for retrievability to drop from 100% to 90% | 0+ days |
| **Retrievability (R)** | Probability of successful recall right now | 0-1 |

### Difficulty at Extraction Time

Claude predicts `predictedDifficulty` (1-10) based on:
- Number of prerequisite concepts needed
- Abstract vs concrete nature
- Whether answer requires recall, explanation, or synthesis
- Information density of the answer
- Confusion potential with similar concepts

This prediction becomes FSRS's initial D₀. FSRS then adjusts via mean reversion after each review:

```
D′(D,G) = w₇ · D₀(3) + (1 - w₇) · (D - w₆ · (G - 3))
```

**Mean reversion prevents "ease hell"** — even wrong predictions self-correct.

### Desired Retention by Graph Position

FSRS allows per-concept `desired_retention` (target recall probability):

| Graph Position | Desired Retention | Reasoning |
|---|---|---|
| Hub concepts (many dependents) | 0.95 | Forgetting blocks downstream concepts |
| Standard concepts | 0.90 | Default FSRS target |
| Leaf concepts (no dependents) | 0.85 | Nothing downstream is blocked |
| Guardian-protected concepts | 0.97 | Game mechanic: guardians keep clusters strong |

This replaces the crude `1.5x interval` repair mission multiplier with principled retention targets.

## SM-2 Legacy (cards without predicted difficulty)

Existing cards with `difficulty == null` use SM-2 scheduling until migrated:

### New Card Defaults (SM-2)

```
easeFactor: 2.5    # Fixed starting difficulty
interval: 0        # Due immediately
repetitions: 0     # No successful reviews yet
nextReview: now()  # Due immediately upon creation
lastReview: null   # Never reviewed
```

### SM-2 Quality Grades (0-5)

| Grade | Meaning |
|---|---|
| 0 | Complete blackout |
| 1 | Incorrect, but recognized on reveal |
| 2 | Incorrect, but answer felt easy |
| 3 | Correct with serious difficulty |
| 4 | Correct with some hesitation |
| 5 | Perfect response |

### SM-2 Scheduling

- **Failed (quality < 3):** interval=1, repetitions=0, ease factor adjusted down
- **Passed (quality >= 3):** repetitions++, interval progression: 1→6→round(interval*EF)
- **Ease factor update:** `newEF = oldEF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))`, min 1.3

### FSRS Rating Scale (4 grades)

| Rating | Meaning |
|---|---|
| Again | Failed to recall |
| Hard | Recalled with significant difficulty |
| Good | Recalled with some effort |
| Easy | Recalled effortlessly |

Note: Quiz screen UI must be updated when migrating from SM-2 (0-5 scale) to FSRS (4-grade scale).

## Why Extraction Quality Matters for Scheduling

### Too easy → wasted reviews (both algorithms)
- SM-2: ease factor climbs, intervals grow fast, item drifts away
- FSRS: low difficulty + high ratings → stability grows naturally (correct behavior)

### Too hard → frustration (SM-2 is worse)
- SM-2: ease factor drops to 1.3, stuck in daily review forever ("ease hell")
- FSRS: mean reversion prevents death spiral, card adapts over time

### Right level → lasting knowledge (FSRS is better calibrated)
- SM-2: all cards start equal, no way to know difficulty until first review
- FSRS: Claude's difficulty prediction means first interval already accounts for complexity

### Auto sub-concept suggestion
- If `predictedDifficulty > 8`, flag for splitting — the card likely tests multiple ideas
- Each sub-concept should have difficulty 4-6 after splitting

## Concept Unlocking and Dependencies

The `GraphAnalyzer` uses "depends on" relationships to determine unlock order. **This is orthogonal to scheduling** — unlocking rules stay the same regardless of SM-2 vs FSRS:

1. Concepts with NO incoming "depends on" edges are **foundational** (always unlocked)
2. A concept is unlocked when ALL its prerequisites have at least one quiz item with `repetitions >= 1` (SM-2) or `stability > 0` (FSRS equivalent)
3. Unlocking is **graph-wide** (not scoped by collection)
4. Quiz session item selection CAN be scoped by collection

### Impact on extraction:
- Every concept must have at least 1 quiz item to enable the unlock chain
- If `A depends on B` but B has no quiz items, A can never be unlocked
- "depends on" chains increase predicted difficulty for downstream concepts

## Retrievability as Mastery Signal

FSRS provides retrievability (R) as a continuous 0-1 value — much richer than SM-2's binary "has been reviewed" signal. This improves:

- **Knowledge graph mastery colors**: R maps directly to grey→red→amber→green gradient
- **Network health scoring**: `NetworkHealthScorer` can use R instead of heuristic mastery
- **Team mastery snapshots**: Per-concept R values are more granular than SM-2's repetition count
