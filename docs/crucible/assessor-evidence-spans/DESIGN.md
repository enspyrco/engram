# Assessor evidence as cited token ranges, not quoted text

Status: round 2, folded from the round-1 strike (`TEMPER.md`, all four families
RECAST). Replaces the evidence mechanism of the blind assessor merged in
https://github.com/enspyrco/engram/pull/183 (`lib/src/models/assessment.dart`,
`lib/src/services/blind_assessor.dart`).

## Producer first

**The bad outcome.** A card is rated as recalled when the learner did not show it,
so FSRS schedules it after it has been forgotten (over-rating).

**Its producers, and what this design does with each.**

1. *The grader writes its evidence as text, and we match that text back to the
   answer.* Every matching rule let words the learner never wrote pass as theirs:
   two cage-match rounds on PR 183 found a new hole each time (`correct` inside
   `incorrect`, a lone stopword, `5` matching `-5`, one word supporting every
   criterion). **Removed.** The grader cites tokens of the learner's answer; evidence
   is copied from the answer. No matching rule exists.
2. *A miscounted citation that still lands inside the answer.* Models copy text well
   and count badly; a bounds check alone would turn a miscount into credit. **Made
   unable to produce credit:** each citation also carries the exact token text, and
   it resolves only when that text equals the cited slice. A miscount fails closed.
3. *The grader's judgement of whether real words show a criterion.* Only a reader of
   meaning can make it (citing "correct" out of "not correct" uses real words).
   **Cannot be removed;** it is the feature. It is measured by the human-rated
   agreement tool (task 22), against an acceptance threshold set before anything
   is wired to a schedule.
4. *The rating rule.* `ratingFor` maps half credit, and a full answer with a
   misconception, to Hard, and Hard is a successful recall in FSRS, so the interval
   still grows. Cheaper valid citations make this path fire more often. See
   **Rating** below; the choice is Nick's and is recorded there.

**What evidence guarantees, narrowly:** displayed evidence is an exact slice of the
learner's answer. It does not guarantee the slice shows the criterion.

## Design

- **One immutable answer.** `AnswerText` holds the learner's answer exactly as
  written and the tokens derived from it. A token is a maximal non-empty run of
  non-whitespace characters, with its start and end character offsets in the
  untrimmed answer. Nothing is normalized.
- **What the grader sees.** The original answer unchanged (line breaks and
  indentation intact), and the numbered token list derived from it, both inside the
  JSON-encoded user message as data. Token numbers start at 0. Rubric criteria keep
  their own `criterion_index`; the token list is the only sequence the model counts
  in.
- **What the grader returns.** For a met or partial criterion, and for each
  misconception: `{"start": i, "end": j, "text": "<tokens i..j joined by single
  spaces>"}`, with `end` inclusive.
- **`Span`.** Private constructor; built only by `Span.of(answer, start, end, text)`,
  which returns null unless `0 <= start <= end < tokenCount` and `text` equals the
  cited tokens joined by single spaces (raw string equality, no case folding). A
  `Span` holds the token range, the character offsets, and the captured substring of
  the original answer (`answer.substring(startOffset, endOffset)`), so a receipt is
  self-contained and old receipts never move if the tokenizer changes.
- **Lengths.** `CriterionJudgement.met` and `Misconception` require a span of two or
  more tokens. A one-token span may support `partial` only. (Disputed in round 1:
  one number can be complete evidence. Partial credit lets it count without
  letting one lone word earn full marks.)
- **Unresolved citations fail closed.** If any citation, for a criterion or a
  misconception, does not resolve, the whole grading is `GradingFailure.malformed`,
  and the caller falls back to self-rating. A citation the grader got wrong is a
  grader fault, never a learner miss. This deletes `unsupportedCount`,
  `unquotedMisconceptionCount`, and the rating input `misconceived` takes from them;
  `misconceived` is true exactly when the receipt lists a misconception.
- **Grader version.** The prompt digest covers the system prompt, the tool schema
  and a `tokenizerRevision` string. Changing how answers are tokenized is a version
  change.
- **Deleted:** `Quote`, `_words`, `_bare`, the punctuation and bracket patterns, the
  two-word minimum as a matching rule, `unsupportedCount`,
  `unquotedMisconceptionCount`.
- **Kept:** `ratingFor` (subject to Rating below), `Unanswered`, `GradingFailed`,
  `GraderModel`, the agreement tool.

## Rating

Hard is a successful recall in FSRS. Today `ratingFor` gives Hard for at least half
the rubric's credit, and caps a full answer with a misconception at Hard. Both
lengthen the interval. **Nick's decision:** [pending] keep Hard for those cases, or
give Again (the card counts as forgotten and comes back soon).

## Acceptance before wiring

The agreement tool runs the grader on the human-rated set (task 22) and reports:
over-rating (grader higher than the person) separately from overall agreement;
unresolved citations (malformed gradings); judgements citing more than half the
answer; one full-answer range reused across criteria; and one-token partials. The
grader is not wired to any schedule until over-rating is at or below **[pending:
Nick's threshold]**.

## Named tradeoff

- **Scripts without spaces** (Chinese, Japanese, Thai): a run of such text is one
  token, so citations cover whole runs and audit little. Owner: Nick. Cost: weak
  evidence for those answers. Mitigation: the agreement tool reports token counts
  per answer; a word segmenter is added if such answers appear.
- **Relevance** stays unchecked by any type, as producer 3 says; measured, not
  guarded.
