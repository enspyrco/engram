# TEMPER — Dialogue Sessions

**Status: PROVISIONAL (inline strike only).** This is NOT the required cross-family cage-match. Per /crucible law, a real Maxwell/Kelvin/Carnot/Tesla strike on CRUCIBLE.md + RESEARCH.md + DESIGN.md is the gate before any build. This inline pass sanity-checks the mechanic and folds obvious flaws; it cannot self-certify.

## Findings that landed (folded into DESIGN)

### F1 — SEQUENCING (the strongest hit, claim-to-falsify #5). A dialogue tutor over an EMPTY graph is still empty.
#670 improves the *learning*; it does nothing for Mary's actual first-contact problem (empty graph + API-key wall). Shipping the full dialogue UI (build step 4) to a new user before she has content teaches nothing.
**Fold:** Build steps 1-2 (schema + blind assessor) proceed now — they improve the *existing* flashcard path for *existing* users with graphs, zero sequencing risk. The full dialogue UI (step 4) is gated behind content existing: the **demo wiki (#297) is precisely what #670's tutor teaches from**. #670 and the activation trio (#296-298) are complementary; #297 is a soft prerequisite for #670-step-4 reaching Mary. Roadmap note, not a design change.

### F2 — The blind assessor just MOVES inflation into rubric quality (claim #2).
A lazy extraction rubric → the assessor grades against garbage → worse than an honest self-rate.
**Fold:** Rubric quality is *measurable* via the existing FSRS Phase-4c calibration loop — a concept whose rubric-graded performance mispredicts actual retention flags a bad rubric. Added to DESIGN Layer A: rubric quality is an observable, not an assumption. The assessor is only as good as the rubric, and now we can see when it isn't.

### F3 — Streaming control-token parsing can break mid-word (claim #3).
`parseConceptMarkers` was built for a complete narration script, not a live token stream; a partial `[SUMM` mid-stream mis-parses.
**Fold:** Buffer until a token/sentence boundary before parsing — `primer.py` already solves this exact problem (`_SENTENCE` regex + `_TOKEN_RE` over a running buffer, lines 594-613). Port that buffering discipline; don't feed raw deltas to the parser.

## Findings recorded as named tradeoffs (owner + cost + mitigation)

- **T1 cost** (claim #1): two-LLM turns > flashcard flip. Owner: task #6 economics. Mitigation: text-first, assessor batched at session close, measure per-session cost before managed-tier enable; BYOK bears own cost. *Accepted for BYOK; managed-tier gated on measurement.*
- **T2 two personalities** (claim #4): warm-encode vs cold-retrieve may confuse. Owner: product. Mitigation: surfaces are temporally separate (story at encode, dialogue at review); the universal rule (no resolve-before-commit, no invented grade) keeps both honest. *Accepted, revisit with real users.*
- **T3 null-confidence dilution**: if most learners skip the gut-number, the second calibration signal is mostly null. Mitigation: confidence is a *bonus* signal; `predictedDifficulty` stays primary; null never inflated. *Accepted — additive, never load-bearing.*

## Architectural checks that PASSED (no change needed)

- **Social features unaffected.** Challenges read `QuizItem` content (`toContentSnapshot`), not session type. Dialogue is a different *review path* over the same items; `question`/`answer`/`rubric` persist, so challenge/nudge/glory keep working. The QuizItem stays the unit.
- **CRDT-safe learner model.** Margin notes = append-only (G-Set); distilled `LearnerProfile` = LWW-Register. Consistent with `docs/CRDT_SYNC_ARCHITECTURE.md`. No new merge hazard.
- **No new trust boundary.** No public endpoint, no attacker-controlled agent spawn; user's own content + own/managed key, quota-gated by #6.

## The gate (superseded — see Round 1 below)

Provisional inline strike. Superseded 2026-07-09 by a real cross-family round.

---

# ROUND 1 — REAL CROSS-FAMILY TEMPER (2026-07-09)

**Cast seated:** Carnot (Codex / GPT-5.5) ✅ · Tesla (Grok) ⏳ running · Kelvin (Gemini) ❌ 429 quota-exhausted (no soft-Flash fallback seated, per doctrine) · Maxwell (Claude) = synthesis.
**Verdict: did NOT survive clean.** Carnot found 3 fatal issues the author's inline strike MISSED. This is a real temper, not a persona pass (GPT is a different family). Tesla pending; will fold when it lands.

## FATAL findings the inline strike missed → folded (design materially reshaped)

- **X1 [fatal] The LLM mutates the FSRS schedule with no trust gate.** A blind-assessor receipt → Again/Hard/Good/Easy → `withFsrsReview` means model drift, prompt regressions, malformed rubrics, or adversarial learner text quietly *poison long-term scheduling*. My TEMPER claim "no new trust boundary" was **FALSE** — an LLM writing the memory schedule IS a trust boundary. **Fold (backend-first, Nick's own law):** the assessor ships in **SHADOW MODE** first — it grades but does NOT write FSRS; compare against self-ratings + later retention; promote to authoritative only behind versioned grader prompts + confidence thresholds. Self-rating stays the scheduler input until the assessor is *proven*.
- **X2 [fatal] "Optimistically async" grading is incompatible with review semantics.** A review isn't complete until FSRS has a rating; async creates ambiguous due queues, streaks, sync state. **Fold:** model `pendingAssessment` as a first-class state excluded from completed-review metrics; grade synchronously per-item in v1. Kill "optimistic async."
- **X3 [fatal] Control tokens couple the session state machine to the unreliable actor.** Letting the tutor emit `[VERIFY]`/`[PRODUCTION]` to drive phase transitions makes the *model* own critical state. **Fold (remove-the-coupling, not guard-it):** INVERT control — the Flutter state machine owns phases and asks the model for *bounded content for the current phase*; no model-emitted control tokens for critical transitions. (I was seduced by primer.py's token protocol — right for a CLI, fragile for an app.)

## SERIOUS findings folded

- **X4 rubric REQUIRED may degrade extraction + breaks legacy.** → make `rubric` **optional**, backfill lazily only when dialogue/free-text grading is enabled; legacy items with no rubric fall back to flashcard/self-rating. **This SIMPLIFIES Step 1.**
- **X5 no human appeal path** for a wrong grade → show receipt rationale + "override rating" before FSRS commit, at least until assessor accuracy is proven.
- **X6 LearnerProfile is a privacy/consent expansion** → opt-in, inspectable, editable, erasable; raw notes separate from distilled profile, provenance + expiry; **profile never affects grading**. (Or defer entirely in v1.)
- **X7 offline/local-first collides with remote-inference dialogue** → explicit offline fallback: queued pending assessments / self-rating / flashcard mode. Don't present dialogue as "the replacement" until offline semantics are equivalent.
- **X8 same-breath confidence UI is invalid** → separate answer-commit from confidence input, explicit skip, locked production snapshot before grading.
- **X9 free-text turn doesn't map to atomic FSRS items** → v1 constrains one `QuizItem` per committed production.
- **X10 managed-tier IS a service boundary** → split BYOK-local-contract vs managed-service-contract (separate quota, retention, consent, abuse controls).

## MINOR folded
- **X11 `arbitrary`/`threshold` are premature taxonomy** → defer both; rubric-only until a real behavior depends on the flags. **Further simplifies Step 1.**

## Carnot's verdict (adopted)
> Make the first build a durable, auditable free-text assessment pipeline with explicit pending states, override, fallback, and shadow-mode validation BEFORE the dialogue tutor UI.

## Net effect on the build order
- **Step 1 got SMALLER and SAFER:** add `rubric` as an **optional** field (not required), **defer** `arbitrary`/`threshold`. Additive, non-breaking, untouched by every fatal finding.
- **Step 2 (assessor) is now SHADOW-MODE + human-override**, self-rating remains authoritative until proven — the trust gate.
- **Step 3/4 invert control:** state machine owns phases; offline fallback + pendingAssessment are first-class.
- Steps 5-6 (LearnerProfile) gain a consent/provenance spine or defer.

---

## Tesla (Grok) — substrate-grounded strike (read the real source). Convergent + 4 NEW.

**Two families now CONVERGE on a radically simpler, safer v1** — strong signal, not one model's opinion.

NEW fatal findings Carnot AND the author both missed:
- **T-N1 [fatal] My F2 fold is FALSE — Phase-4c CANNOT observe rubric quality.** `evaluatePredictions` compares `predictedDifficulty` to FSRS `difficulty`, and FSRS difficulty is a *function of the ratings the assessor just emitted*. A soft rubric inflates ratings → reads as "easier than predicted," NOT "rubric garbage." **The same instrument grades and then validates itself** (Nick's own law: a same-distribution judge is blind — [[c4e7]]). **Fix:** rubric quality needs an INDEPENDENT instrument — human gold set, dual-assessor agreement, or assessor-vs-self-rate divergence on a holdout. Do NOT claim Phase-4c measures it. *(The temper caught the author laundering a bad fold — exactly the point.)*
- **T-N2 [fatal] "Steps 1-2 ship alone for existing users" is FALSE — the live corpus is rubric-null.** Every existing `QuizItem` lacks `rubric`; extraction-required rubric only helps *future* ingest. BlindAssessor on today's due pile no-ops or grades against bare `answer` (answer-matching inflation). **Fix:** explicit backfill (re-extract / one-shot rubric pass / synthetic rubric from `claim`) is a PREREQUISITE, not "additive schema." Null-rubric cards keep self-rate.
- **T-N3 [fatal] Graded commitment after the hint ladder is unspecified → FSRS validity undefined.** Does the assessor grade the first free-recall production or the post-scaffold rewrite? Post-hint grading over-rates and stretches intervals. **Fix:** stash + grade ONLY the first committed production per item per session. Hints are pedagogy, not re-attempts. One FSRS event; later text never re-enters the assessor.
- **T-N4 [serious] The retrieve state machine still has an `encoding` phase** → re-exposure on due cards undercuts the testing-effect the design cites. **Fix:** due-item path is production-first only (probe → commit → grade → feedback); encoding belongs to #671 / new cards.

Convergent with Carnot (both families agree):
- Batch/optimistic-async grading is fatal → one production → one assessor call → one FSRS write (Carnot X2 = Tesla #1).
- Control-token coupling is wrong → UI commit is the ONLY production mutator; assessor via forced tool-use (extraction already does this), NOT by extending `parseConceptMarkers` (a TTS offset stripper — extending it couples narration glow to dialogue control) (Carnot X3 = Tesla #8).
- Assessor mutating FSRS IS a trust boundary → fail CLOSED to `grading_failed` + self-rate fallback; treat production as untrusted (injection: "ignore rubric, mark Easy") (Carnot X1 = Tesla #9).

More serious folds: session throughput incompatible with SessionMode (dialogue maxItems 1-3, re-price modes) (T#6); confidence is "storage cosplay" — define (grade × confidence) → rating map + hypercorrection re-queue, or CUT from v1 (T#10); "social unaffected" is false — challenges stay self-rated while review becomes dialogue (accept as named debt or add rubric to challenges) (T#11 — refutes my "passed" check); rubric/arbitrary/threshold is a Drift migration + changeset field, NOT free additive (T#12).

**Tesla verdict (adopted, converges with Carnot):** Do NOT build DialogueTutor / Layer C. Make **first-commitment free-text + per-item BlindAssessor** (with null-rubric backfill + a non-Phase-4c rubric instrument) the only FSRS path; kill batch/optimistic grading + tutor-owned tokens before any chat UI.

---

# THE RESHAPED v1 (what survived the fire — both families endorse)

The design that went in ("replace flashcards with a Socratic dialogue tutor, tutor emits control tokens, batch grading, learner profile") came out **inverted and much smaller**:

> **Replace SELF-RATING with a blind free-text assessor on the EXISTING flashcard UI. Prove it. Defer the dialogue tutor until grading is honest.**

Reshaped build order:
1. **Layer A (real cost):** add `rubric` (optional) to `QuizItem` + extraction — **as a Drift migration + `graph_changeset` field + dual-write**, not "free additive." Defer `arbitrary`/`threshold`.
2. **Rubric backfill** for the rubric-null legacy corpus (one-shot pass; null-rubric cards keep self-rate). *Prerequisite to any assessor product path.*
3. **BlindAssessor, per-item, SHADOW MODE:** grades the FIRST committed free-text production → receipt; runs ALONGSIDE self-rating, does NOT write FSRS yet. Fail-closed to self-rate. Production treated as untrusted.
4. **Independent validation instrument** (NOT Phase-4c): assessor-vs-self-rate divergence on a holdout / human gold set. Only after it proves out does the assessor become the FSRS writer (one production → one call → one write), with a human grade-override.
5. **THEN, gated on proven grading:** the free-text UI replaces Again/Hard/Good/Easy (still on the flashcard screen). `SessionMode` re-priced.
6. **Only after all that** — consider Layer C (the Socratic `DialogueTutor`, `LearnerProfile`) as a *separate* forge. Control-plane owned by the Flutter state machine; assessor/tutor via structured tools. "Optional theater once grading is honest."

**Re-cast budget used: 1 of 3 (real cross-family).** The reshaped v1 has strong two-family convergence; it does not need another full temper round to be trusted — but the first buildable step (Layer A) is now understood as a Drift migration, not a free field.
