# DESIGN — Dialogue Sessions (#670)

Cast-phase mold. What to build, in what order, with what tradeoffs. Grounded in `RESEARCH.md`.

## Problem

Engram's learning surface is a generic flashcard deck (`QuizPhase.idle→question→revealed→summary`). It doesn't teach — it tests recall of a canned answer. The product goal (#670, #671, activation gap) is a **tutor that teaches like a mind**: generation-first, honestly graded, and that *learns the learner*. Two reference implementations exist and agree; the schema to support them does not yet.

## Shape

Three layers, each independently useful. The invariant across all: **never resolve before commitment; never invent a grade or confidence.**

### Layer A — the grading contract (schema)
Additive fields, no migration break (both models already tolerate missing fields via `fromJson`):
- **`QuizItem.rubric: List<String>?`** — 2-4 grading criteria ("names both terms", "explains why normalization is needed"). The blind assessor's contract.
- **`QuizItem.arbitrary: bool` (default false)** — non-derivable content (terminology, brute facts) → mnemonic path, skip derivation theater.
- **`QuizItem.threshold: bool` (default false)** — portal concept → extra scaffolding / an artifact.
- Extraction tool schema (`extraction_service.dart`) gains `rubric` (required, 2-4 strings) + optional `arbitrary`/`threshold` on both the main and sub-concept `quizItems` schemas. Prompt gains: "the `question` is a free-recall probe — it must NOT contain or leak the answer."
- `toJson`/`fromJson`/`toContentSnapshot` updated; `rubric` omitted-when-null for back-compat.

### Layer B — the dialogue engine (pure, testable, no UI)
- **`DialogueTutor`** — wraps an `anthropic_sdk_dart` streaming call with the generation-first system prompt (ported from nagisanzenin's `dialogue-grammar.md`, warmth-dialed by surface). Emits control tokens parsed by the **existing `parseConceptMarkers`** infra (extended with a small token grammar: `[VERIFY]`, `[PRODUCTION]…[/PRODUCTION]`, `[NOTE_LEARNER:]`).
- **`BlindAssessor`** — a *separate* `anthropic_sdk_dart` call that receives only `{claim, rubric, probe, production, confidence}` (never the dialogue) and returns strict receipt JSON `{grade, rating, misconceptions, rubric_notes, feedback_line}`. Grade→rating maps to the existing Again/Hard/Good/Easy → `withFsrsReview`.
- **`DialogueProduction`** — the learner's committed answer + confidence (`int?`, null-if-declined), persisted to Drift **the moment it exists** (context-loss safety), before grading.
- **`LearnerProfile`** — cross-topic profile (the `learner.md` analogue), distilled at session close from `[NOTE_LEARNER]` observations. Stored locally (Drift), read at session start. **This is the "learns you" thesis made concrete.**

### Layer C — the UI (replace the flashcard screen)
- New `DialogueSessionState` (replaces/extends `QuizSessionState`): a turn list, current production, phase (`greeting→encoding→verifying→grading→closing`), pending-grade queue.
- `DialogueScreen` — chat-style turns; the tutor streams, the learner commits a production + a gut 0-100 confidence in the same field, the verdict returns as a feedback line. Text-first v1 (no mic).
- FSRS wiring unchanged: a graded production → `withFsrsReview` → existing scheduler. Confidence stored as the second calibration signal alongside `predictedDifficulty`.

## Build order (core-first, each step ships value alone)

1. **Layer A schema** — `rubric`/`arbitrary`/`threshold` on model + extraction + tests. *Ships value alone:* richer extraction, backfillable, unblocks everything. **Start here (the falsified critical path).**
2. **`BlindAssessor` (pure)** — grade a `{production, rubric, probe, claim, confidence}` → receipt JSON, mapped to FSRS rating. Unit-tested against fixtures. *Ships alone:* a better grader even for the *existing* flashcard reveal (grade free-text instead of self-rated Again/Hard/Good/Easy).
3. **`DialogueTutor` + token grammar** — generation-first single-node loop, control tokens via extended `parseConceptMarkers`. *Ships alone:* a "dialogue mode" toggle on one concept.
4. **`DialogueSessionState` + `DialogueScreen`** — full session over FSRS-due/gap concepts. Replaces `quiz_screen` behind a setting flag.
5. **`LearnerProfile` + margin notes** — personalization layer; distill at close. *Ships alone:* "it remembers how you learn."
6. **(Later / #671)** story-shaped encode surface reusing Layer B; **(Later)** mic/STT.

## Tradeoffs taken (named, with owner)

- **Two-LLM turns cost more than a flashcard flip.** Owner: gates on task #6 (managed-AI economics). *Mitigation:* text-first, batch the assessor at session end (not per-node) in v1, measure cost per session before enabling for managed-tier users. BYOK users bear their own cost.
- **Blind assessor adds latency** (extra call). *Mitigation:* batch at session close; grade optimistically-async so the dialogue never blocks on grading.
- **Warmth vs rigor is surface-dependent, not global.** Accepted: review surface is disciplined (Mary may find it "harder" than a flashcard), story surface is warm. *Mitigation:* the one universal rule (no resolve-before-commit, no invented grade) keeps warmth honest.
- **`QuizSessionState` isn't deleted day one** — dialogue lives behind a flag until proven. Accepted debt: two session paths briefly coexist.

## Blast-radius & consent spine (cage before monster)

- **No new public endpoint / no attacker-controlled agent spawn.** The tutor/assessor are called with the *user's own* content + their own API key (BYOK) or the managed tier (already quota-gated by task #6). Blast-radius owner = the same per-user quota infra #6 builds.
- **Injection surface:** learner productions + ingested document text are untrusted. They enter the API as structured message content, never string-concatenated into a system prompt. The assessor grades only the learner's verbatim production, treating tutor bracket-notes as context, never as the learner's words (nagisanzenin's rule, ported).
- **Cost blast-radius:** a runaway dialogue loop burns tokens. *Mitigation:* per-session turn cap + mode budget (Sprint/Standard/Deep), same as nagisanzenin's mode caps.
- **Data:** productions persist to Drift (local-first); no new cloud surface. FSRS state changes go through the existing `withFsrsReview` door.

## Claims to falsify (for the adversary at Temper)

1. **The two-LLM turn is affordable enough to ship** even to managed-tier users, OR text-first + batched-assessor keeps it viable. *(Could be wrong: cost may force BYOK-only, shrinking the activation win.)*
2. **A blind assessor grading free-text is more trustworthy than learner self-rating** — and doesn't just move the inflation problem into the rubric quality. *(Could be wrong: a bad rubric grades worse than an honest human self-rate.)*
3. **Reusing `parseConceptMarkers` for tutor control-tokens is sound** — the narration marker grammar extends cleanly to dialogue control without collision. *(Could be wrong: streaming partial tokens mid-word may break parsing.)*
4. **Warmth-in-encode / rigor-in-retrieve is the right split** and doesn't just confuse Mary with two personalities. *(Could be wrong: consistency may matter more than optimality.)*
5. **This is higher-impact than shipping the activation-gap trio (#296/#297/#298) first.** *(Could be wrong: a beautiful tutor with no first-run content still leaves Mary at an empty graph — sequencing risk.)*

## Rejected alternatives

- **Just bolt a chat UI onto the existing flashcard** — rejected: no grading contract, so it's a chatbot that can't drive FSRS honestly (the whole point).
- **Persona-in-one-prompt (tutor + grader same call)** — rejected: destroys separation of powers; the grader is influenced by rapport, inflating the schedule.
- **Port `primer.py` wholesale** — rejected: primer is the *encode/story* surface (warm, tell-first); #670 is the *retrieve* surface (generation-first). Wrong half. primer is the seed for #671.
- **Voice-first v1** — rejected for v1: STT is an unresolved design axis; text-first ships the pedagogy without blocking on mic/whisper.

## Open variables (not silently resolved)

- `[CONFIRM]` v1 = text-only (recommended), mic deferred? 
- `[CONFIRM]` assessor batched-at-close (recommended) vs per-node?
- `[CONFIRM]` sequencing vs the activation trio (#296-298) — which ships first? (Claim-to-falsify #5.)
