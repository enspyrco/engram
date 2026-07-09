# RESEARCH — Dialogue Sessions

Heat-phase findings. Grounded in the **real** engram source (read 2026-07-09), the two reference implementations, and the learning-science citations the references carry.

## 1. Engram's real substrate (verified, not from CLAUDE.md)

| Artifact | State today | Relevance |
|---|---|---|
| `extraction_service.dart:117-144` | `quizItems` schema: `required [id, conceptId, question, answer]` + optional `predictedDifficulty` (1-10, FSRS D₀ seed) | **No `rubric`, no `arbitrary`/`threshold`.** The schema gap. |
| `models/quiz_item.dart` | `QuizItem`: id, conceptId, question, answer, full FSRS state (interval, nextReview, difficulty, stability, fsrsState, lapses, `predictedDifficulty` write-once, `reviewCount`). `toJson`/`fromJson` auto-migrate. `toContentSnapshot()` for challenges. | `question`=probe, `answer`=canonical claim. Missing: `rubric`, classification flags. Additive change. |
| `models/quiz_session_state.dart` | `QuizPhase{idle,question,revealed,summary}`, `IList<QuizItem> items`, `ratings` as `IList<int>` (r≥3 = correct). | The flashcard state machine #670 replaces. `ratings` has **no confidence, no per-node production text.** |
| `engine/concept_marker_parser.dart:33` | `parseConceptMarkers(annotatedText)` → `MarkerParseResult` (used by narration) | **Reusable** for parsing tutor control-tokens from an LLM stream. |
| `services/extraction_service.dart` | Uses `anthropic_sdk_dart` `Tool.custom` with forced tool-use; `defaultExtractionModel='claude-sonnet-4-5'`. | The pattern to follow for tutor + assessor API calls. |
| FSRS | `withFsrsReview`, `predictedDifficulty` + `reviewCount` + `evaluatePredictions()` (Phase 4). Ratings map to fsrs Again/Hard/Good/Easy. | Grade→rating→FSRS path exists. Confidence would be a **new** second calibration signal alongside `predictedDifficulty`. |

## 2. The two reference implementations — mechanism diff

| Dimension | `primer.py` (ENCODE) | `nagisanzenin` (RETRIEVE) |
|---|---|---|
| Core loop | TELL-first in morsels; ends turn with an **invitation, not a quiz** | GENERATION-first 8 beats: gap→predict→struggle(hint ladder)→resolve→self-explain→connect→verify→close. **Never resolve before commitment.** |
| Examiner | KERNEL: a second Mind (Haiku), in-fiction character, warm when learner falters | **Blind assessor**: separate agent, sees only `{claim, rubric, probe, production, confidence}`, never the lesson. Returns receipt JSON. |
| Separation of powers | Soft (Kernel converses, can be warmed) | **Hard** (grader cannot be influenced by rapport — anti-inflation) |
| Confidence | none | Same-breath ask; **null if declined; never invented.** High-confidence errors = hypercorrection treasure. |
| Anti-sycophancy | "warm, a little playful, never twee" | Explicit oath w/ citations (below) |
| Learner model | **`learner.md`** cross-topic profile, distilled from `[NOTE LEARNER]` margin notes at session close | per-topic `model` (interests, strategy_weights, challenge_band) |
| Wire protocol | Text tokens (`[SUMMON KERNEL:]` etc.) parsed from stream | Shell state via `engram.py` (`stash add`→assessor→`receipt`→`stash clear`) |
| Node schema | book map (waypoints, pictures, alternates) | `claim`, `probe` (leak-free), `rubric` (2-4 criteria), `transfer_probe`, `arbitrary`, `threshold`, edges |
| Safety | — | **learner text never on a shell command line** (injection); **stash the moment a production exists** (context-loss safety) |

## 3. Learning-science citations (carried by nagisanzenin's grammar; worth honoring)

- **Testing/retrieval effect** — retrieval practice beats re-exposure for retention → the generation-first discipline for the RETRIEVE surface.
- **Pretesting effect** — a wrong guess *before* learning improves what sticks.
- Controlling praise nets **negative** on adult intrinsic motivation (Deci/Koestner/Ryan 1999, d=−0.78) → "encouragement is information, never pressure."
- Sympathy reads as a low-ability cue (Graham 1984; Brummelman 2014) → "absolve, never pity" after a lapse.
- Over-helpful tutor harms retention once removed (Bastani 2025) → warmth is *the same withheld help, kindly framed*, not more help.
- "Teach relevance, don't preach it" (Canning & Harackiewicz 2015) → elicit the goal-link, don't lecture it.
- Hypercorrection — high-confidence errors, once corrected, are unusually durable → spotlight + re-derive + log misconception.

## 4. Prior art / constraints for the Flutter port

- **Two-LLM turn cost**: each dialogue turn is ≥1 tutor call; grading adds an assessor call (batchable). Materially more expensive than a static flashcard flip → gates on task #6 (managed-AI tier / cost caps). Measure before committing to per-node grading.
- **STT in Flutter**: `speech_to_text` plugin (on-device, free, lower accuracy) vs whisper (heavier). Text-first v1 sidesteps this entirely.
- **Streaming**: `anthropic_sdk_dart` supports streaming; the marker-parser already handles incremental text → tutor control-tokens can be parsed live.
- **Context-loss safety**: nagisanzenin's "stash productions immediately" maps to persisting the learner's production to Drift *before* grading — aligns with Engram's local-first/CRDT posture.
- **Injection**: learner productions + document text are untrusted; in Flutter they go into the API as structured content (lower risk than a shell), but the tutor's output drives FSRS state, so the assessor must grade only the learner's actual words, never tutor-inserted bracket notes.

## 5. LLM-grading literature (searched 2026-07-09) — validates the temper, hands us knobs

**The exact combo (LLM-graded free recall → SRS scheduling) is a LIVE 2025-26 frontier, mostly "work in progress":**
- **LECTOR** (arXiv 2508.03275, Aug 2025) — LLM semantic-similarity assessment wired into spaced-repetition scheduling. Closest published analogue to #670.
- **ASEE WIP** — *Enhancing Active Recall and Spaced Repetition with LLM-Augmented Review Systems* — LLM grading of recall feeding the scheduler.

**Automated short-answer grading (ASAG) is mature — consensus = AI-HUMAN HYBRID, not full-auto:**
- LLMarking (ACM L@S 2025); EvalCouncil (committee-and-chief + human adjudication). Recurring conclusion: "reliability limited by instability + bias; human oversight required; hybrid optimizes." → **confirms human-override + monitor, deflates the elaborate shadow-mode.** (Nick's push was right.)
- Clinical short-answer calibration (PMC12896245): rubric-based LLM grading viable but needs SME adjudication on ambiguous cases.

**LLM-as-judge bias is well-studied — names the failure mode + gives design knobs:**
- **Leniency is prompt-driven + systematic:** a detailed/structured rubric prompt scores HARSHER; a minimal prompt scores MORE LENIENT — same answer. → the grading prompt is a calibration knob; **version it, fix it, never tweak casually** (arXiv 2506.22316).
- **Grading scale:** human-LLM alignment HIGHEST on a **0-5 scale** (arXiv 2601.03444). Engram's 4-point Again/Hard/Good/Easy is close — revisit before locking.
- **Mid-range degradation:** LLM graders agree with humans at the EXTREMES, degrade on PARTIAL answers — exactly the `Hard`↔`Good` boundary FSRS is most sensitive to. → **point human-override at the mushy middle, not everywhere** (arXiv 2605.07647).
- **Verbalized confidence is poorly calibrated;** sampling-consistency calibrates better (arXiv 2602.00279). → deflates the "ask for a gut 0-100" confidence idea; if kept, prefer consistency-across-samples over a self-reported number.

**The GAP Engram can own:** nearly all ASAG grades answers for a *grade* (assessment). Almost nobody grades free recall to drive a *schedule* and then measures **downstream retention** (only ~1 AI-pretesting retention study, arXiv 2606.22328). **Engram already has the FSRS retention loop** → it can run the experiment the papers can't: *does LLM-graded scheduling beat self-rating on real retention?* Publishable, and it lives inside the roadmap.

Sources: arXiv 2508.03275 (LECTOR) · nemo.asee.org/.../46477 (ASEE) · dl.acm.org/10.1145/3698205.3729551 (LLMarking) · arXiv 2601.03444 (grading scale) · arXiv 2506.22316 (scoring bias) · arXiv 2605.07647 (mid-range degradation) · arXiv 2602.00279 (confidence calibration) · arXiv 2606.22328 (retention) · PMC12896245 (clinical calibration).
