# Assessor evidence as copied tokens, located by engram

Status: round 3, folded from round 2 (`TEMPER.md`: two rounds, all four families
RECAST both times, converging). Replaces the evidence mechanism of the blind assessor
merged in https://github.com/enspyrco/engram/pull/183
(`lib/src/models/assessment.dart`, `lib/src/services/blind_assessor.dart`).

## Producer first

**The bad outcome.** A card is rated as recalled when the learner did not show it,
so FSRS schedules it after it has been forgotten (over-rating).

**Its producers, and what this design does with each.**

1. *The grader writes evidence text and we fuzzy-match it back.* Every matching rule
   let words the learner never wrote pass as theirs (two cage-match rounds on PR 183
   found a new hole each time). **Removed:** matching is exact equality of whole
   tokens; there is no normalization to have holes in.
2. *The grader counts positions.* Models copy well and count badly; any protocol
   that asks for positions turns miscounts into wrong credit or failed gradings.
   **Removed:** the grader never returns a number. It copies tokens; engram locates
   them.
3. *A failed grading falls back to something that can lengthen the interval.*
   Self-rating can mark a success, and it is the rating the grader exists to replace.
   **Removed:** a failed grading writes nothing to FSRS. The card stays due.
4. *The rating rule.* Hard is a successful recall in FSRS. **Restructured (Nick,
   2026-11-24):** Hard only when nothing was missed and there is no misconception.
5. *The grader's judgement of whether real words show a criterion.* Only a reader of
   meaning can make it ("correct" can be cited out of "not correct"). **Cannot be
   removed;** it is the feature. Measured by the agreement tool before wiring.

**What evidence guarantees, narrowly:** displayed evidence is an exact slice of the
learner's answer. It does not guarantee the slice shows the criterion.

## Design

- **One immutable answer.** `AnswerText` holds the answer exactly as written and the
  tokens derived from it: maximal non-empty runs of non-whitespace, each with its
  character offsets in the untrimmed answer. Nothing is normalized.
- **What the grader sees.** The original answer unchanged (line breaks and
  indentation intact), and the token list as a JSON array of strings, both as data
  in the JSON-encoded user message.
- **What the grader returns.** For a met or partial criterion, and for each
  misconception, `"evidence": ["tok", "tok", ...]`: one or more consecutive tokens
  copied from the list. No positions.
- **`Span`.** Private constructor; built only by `Span.find(answer, tokens)`, which
  returns the first place in the answer where those tokens occur consecutively, by
  raw string equality, or null. Repeated phrases resolve to the first occurrence;
  the credit is the same wherever they occur. A `Span` holds the token range, the
  character offsets and the captured substring of the original answer, so a receipt
  is self-contained.
- **No length rule.** One token can fully meet a criterion ("Paris", "42", "-5") or
  carry a misconception ("Yes" to "Is the earth flat?").
- **Failed gradings.** If any citation does not resolve, or the tool call is missing
  or malformed, the outcome is `GradingFailed`. **A `GradingFailed` never writes to
  FSRS:** the card stays due and comes back. The conversation may still ask the
  learner how it went, but that answer cannot move the schedule.
- **Grader version.** The digest covers the system prompt, the tool schema, and the
  tokenizer's pattern constant (`\S+`) and its offset rule. Changing how answers are
  tokenized changes the version without anyone remembering to. Receipts store the
  judgements, not a rating; the rating is derived by a named `RatingPolicy`, and
  every report names the policy it used.
- **Deleted:** `Quote`, `_words`, `_bare`, the punctuation and bracket patterns, the
  two-word minimum, `unsupportedCount`, `unquotedMisconceptionCount`, and the
  self-rating fallback's write to the schedule.
- **Kept:** `Unanswered`, `GradingFailed`, `GraderModel`, the agreement tool.

## Rating (`RatingPolicy.nothingMissed`, Nick 2026-11-24)

- **Good:** every criterion met, and no misconception.
- **Hard:** no criterion missed, at least one only partial, and no misconception.
- **Again:** any criterion missed, or any misconception.

The grader never gives Easy.

## Acceptance before wiring

The human-rated gold set (task 22) is split before anything runs: a calibration part
and an untouched evaluation part.

The agreement tool reports, naming the grader version and rating policy:

- **Coverage:** the share of answered items that were graded (not `GradingFailed`),
  with the failed items and the tokens that would not resolve.
- **Over-rating:** among graded items, the share the grader rated higher than the
  person. Failed items count as "no schedule change", which cannot over-rate.
- Judgements citing more than half the answer, and one citation reused across
  criteria (the lazy-evidence residual of producer 5).

On the calibration part, Nick sets an over-rating threshold and a coverage bar
(his decision: after the first run). They are committed with the calibration
report, then frozen, and the grader is wired to a schedule only if the evaluation
part meets both.

## Named tradeoffs

- **Scripts without spaces** (Chinese, Japanese, Thai) and single code blobs or URLs
  are one token, so citations cover whole runs and audit little. Owner: Nick. Cost:
  weak evidence for those answers; grades still work. Mitigation: the agreement
  tool reports token counts; a word segmenter is added if such answers appear.
- **Relevance** (producer 5) is measured, not guarded.
