# CRUCIBLE — Dialogue Sessions (replace flashcards with primer-style Socratic dialogue)

**Ore selected:** #670 — replace Engram's flashcard quiz with primer-style two-mind Socratic dialogue.
**Date:** 2026-07-09 · **Forge:** /crucible · **Status:** hot-phase (pre-temper)

## The pick, and why it glows

Engram's learning surface today is a flashcard deck: `QuizPhase.idle → question → revealed → summary`, rate Again/Hard/Good/Easy. It *works*, but it is the generic SRS interaction every competitor has. Nick's product call (2026-06-11): **"replace engram's flash cards with what the primer does."**

This session found **two independent, complete reference implementations** of the target pedagogy that *agree on the road*:

1. **`primer.py`** (Nick's own, `~/git/individuals/nickmeinhold/primer/`) — an 894-line Diamond-Age engine: a warm PRIMER mind (teacher) + a KERNEL mind (examiner), a token wire-protocol (`[SUMMON KERNEL]` / `[TRIAL COMPLETE: passed|struggled]` / `[KERNEL ACCEPTS]` / `[THE BOOK RESTS]`), a cross-topic `learner.md` distilled from `[NOTE LEARNER]` margin notes, and it **already emits Engram-schema `graph.json` + `review_events.jsonl`** (the #669 bridge).
2. **`nagisanzenin/engram`** (independent, MIT) — a generation-first 8-beat dialogue grammar, a **blind assessor** (grader deliberately isolated from the tutoring dialogue), confidence integrity (same-breath / null-if-declined / never-invented), an anti-sycophancy oath with citations, and a curriculum-architect node schema carrying `probe` + `rubric` + `arbitrary`/`threshold`.

## The synthesis finding (the load-bearing idea)

**They are not competitors — they are the two halves of Engram's own loop.**
- `primer.py` = the **ENCODE** surface: warm, tell-first, learner-as-protagonist, story-shaped → this is #671 (illustrated story mode).
- `nagisanzenin` = the **RETRIEVE** surface: generation-first, blind-graded, calibration-honest → this is #670 proper (the flashcard replacement).

Design consequence: **warm in encode/story, disciplined in review/retrieve.** One rule holds in *both*: never resolve before a commitment; never invent a grade or a confidence number.

## Why it matters (impact, not affect)

- Removes a real thing: the rote flashcard loop, replaced by a tutor that teaches like a mind. Directly serves the "mind-blowing for Mary" activation bar (`concept_engram_activation_gap`).
- Unblocks #671 (story mode shares the two-mind + learner-model spine) and completes #669 (the primer data bridge already exists).
- Feeds the existing FSRS Phase-4 calibration loop a second signal (learner confidence) it currently can't capture.

## The falsifier (fired 2026-07-09, against real source — SURVIVED)

**Claim that could be slag:** *"Extraction already emits a grading rubric + leak-free probe, so the tutor/assessor are not blocked on a schema gap — the whole build is just a chat UI."*

**Verification:** `extraction_service.dart:122` requires `['id','conceptId','question','answer']` (+ optional `predictedDifficulty`). **No `rubric`, no `arbitrary`/`threshold`, no confidence capture in `QuizSessionState.ratings` (List<int>).** The blind assessor's grading contract genuinely does not exist. **Ore is real.**

## Remaining open variables (not yet resolved — for Cast/Temper to close)

- `[OPEN]` Voice/STT in-app: text-only v1, or mic (speech_to_text vs whisper)? (primer is voice; Flutter mic is an open question per #670.)
- `[OPEN]` Does the blind assessor run per-node (latency ×N) or batched at session end (context-loss risk)?
- `[OPEN]` Default warmth level for the review surface — how cold is too cold for Mary?
- `[OPEN]` Cost/latency of a two-LLM dialogue turn vs a static flashcard (managed-AI tier economics, task #6).
