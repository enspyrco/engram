# TEMPER.md — assessor evidence as word ranges

**Overall verdict:** RECAST (round 1 of at most 3)
**Struck:** dt-1795484576, families seated: Maxwell + Noether, Carnot, Tesla (Wu disabled). Arrival order: Maxwell, Noether, Carnot, Tesla.

Bundle: `DESIGN.md`, `lib/src/models/assessment.dart`, `lib/src/services/blind_assessor.dart`. Cited-but-not-sent check: 0 not sent.

## Per-family verdicts

| Family | Verdict | One line |
|---|---|---|
| Maxwell (Claude) | RECAST | Citations make credit auditable but guard almost nothing about the rating; an invalid citation is a grader fault, so fail closed. |
| Noether (DeepSeek) | RECAST | The grader version no longer names the whole grading function (the tokenizer isn't hashed); `Span` has no stated state; ordinal indices invite off-by-one. |
| Carnot (GPT) | RECAST | A whitespace token list erases line breaks the grader needs; provenance is not support; the design names no acceptance test. |
| Tesla (Grok) | RECAST | An in-range miscount fails OPEN into credit; bind each citation to the exact token text so a miscount fails closed. |

## Fatal flaws (deduped, most severe first)

1. **An in-range wrong index becomes credit (fails open).** Models count badly and copy text well. — Tesla, Noether (ordinal addressing), Maxwell (degenerate ranges). DISPOSITION: fold. A citation carries `start`, `end` AND the exact token text; `Span.of` returns null unless the text equals the slice by raw string equality. A miscount then fails closed.
2. **An unresolved citation is counted as a learner miss (or a misconception cap), mixing grader faults into ratings.** — Maxwell, Tesla, Noether (semantic drift of `unsupportedCount`). DISPOSITION: fold. Any unresolved citation, for a criterion or a misconception, makes the whole grading `malformed` (fail closed to self-rating). `unsupportedCount` and `unquotedMisconceptionCount` are deleted, along with their rating input.
3. **The grader sees a whitespace-split list, losing line breaks and indentation.** — Carnot; Tesla (empty tokens from `split`); Maxwell (no whitespace in CJK). DISPOSITION: fold. The grader receives the original answer unchanged AND a numbered token list derived from it. Tokens are maximal non-empty runs of non-whitespace, with character offsets into the untrimmed answer. Scripts without spaces (CJK, Thai) become one token per run: **named tradeoff**, owner Nick; cost: weak evidence auditing for those answers; mitigation: the agreement tool reports token count per answer, and a segmenter is added if non-spaced answers appear.
4. **`GraderVersion` no longer names the whole grading function.** The tokenizer and the citation policy live in code, outside the digest. — Noether, Tesla. DISPOSITION: fold. The digest also covers a stated `tokenizerRevision` string; changing the tokenizer is a version change.
5. **`Span`'s state is unstated.** — Noether, Tesla. DISPOSITION: fold. `Span` holds the token range, character offsets, and the captured substring, so a receipt is self-contained.
6. **The safety claim is broader than the mechanism.** A cited range proves the words are the learner's, not that they show the criterion (e.g. citing "correct" out of "not correct"). — Carnot, Maxwell. DISPOSITION: fold. Guarantee stated narrowly: evidence is an exact source slice; relevance, omitted negation and contradictory context are the grader's judgement, measured by the gold set.
7. **One-token evidence.** — DISPUTED: Carnot allows it (one number can be complete evidence); Noether and Tesla want a floor; Maxwell frames evidence as audit. DISPOSITION: fold Tesla's middle ground. A one-token span may support `partial` only; `met` and a shown misconception need two or more tokens.
8. **The rating rule is coupled to the stated harm.** Hard is a successful recall in FSRS, so half credit or a capped full answer still lengthens the interval, and cheaper in-range credit makes that path fire more often. — all four. DISPOSITION: **Nick's decision, recorded in the design's rating section**, not deferred beside it.
9. **No acceptance test.** — Carnot, Maxwell (maximal ranges), Tesla. DISPOSITION: fold. Before any wiring, the agreement tool compares graders on the human-rated set and reports over-rating ("false successful recall") separately, plus unresolved citations, full-answer ranges reused across criteria, and one-token partials. **Acceptance threshold: Nick's decision.**

## What holds

- Deleting the text matcher (`Quote`, `_words`, `_bare`, the punctuation rules) is right, all four agree: it removes the producer the cage-match kept finding holes in.
- Evidence is a slice of the learner's own bytes, so fabricated words are unrepresentable rather than detected.
- `ratingFor` stays code, `Unanswered` and `GradingFailed` stay, and relevance is honestly named as unremovable and measured.

## Disposition

RECAST: flaws 1-7 and 9 fold into `DESIGN.md`; flaws 8 and 9's threshold wait on Nick; then re-strike (round 2 of at most 3).

---

<!-- Per-family strikes, in arrival order, written as each returned. -->

## MaxwellMergeSlam's Design Strike

**Verdict:** RECAST

**Summary:** Word ranges correctly delete the fabricated-quote producer, but the design still calls evidence a guard against over-rating, and it guards almost nothing: a grader can always cite real words, including the whole answer.

**Producer first:** The bad outcome is over-rating. Its producers: (1) the grader writing evidence text that we must match back. The design removes this, and that holds. (2) The grader's judgement of relevance, which cannot be removed. But the design never states the consequence of (2) for the check it keeps. If every met criterion may cite *any* real range, including `{start: 0, end: n-1}` (the whole answer), then "a valid range exists" reduces to "the answer is non-empty", which `Unanswered` already covers. The downgrade rule "invalid range → missed" is a check whose producer (a grader that cites badly) is also a grader that can trivially cite validly. So the evidence check guards nothing about the rating. What it truly does is make credit AUDITABLE: a person can see exactly which of their words were credited. Treat evidence as audit, not as a rating guard.

**Fatal flaws:**
- **Wrong option-frame (DESIGN.md "Producer first", point 1, and "Design: Span").** The design frames citations as the thing that stops over-rating, so it keeps "out-of-range citation → criterion missed", a guard. Out-of-range is not a sign of over-rating; it is a sign of a malfunctioning grader (miscounted or hallucinated indices). Downgrading it to "missed" silently mixes grader faults into the ratings the gold set measures. Fold: an invalid range makes the whole grading MALFORMED (fail closed to self-rating), and evidence is described as audit only. The over-rating protection is the human-agreement measurement, stated as such.
- **Unstated assumption: whitespace marks words (DESIGN.md "Tokens").** For Chinese, Japanese or Thai answers there is no whitespace, so the whole answer is one token, every citation is the whole answer, and the audit value collapses to nothing. Engram's wiki content is not guaranteed to be English, and chat answers even less so. Fold: split on Unicode word boundaries (a word-break segmenter), or on characters for scripts without spaces, and say which.
- **Missing degenerate state: the maximal range.** Nothing stops a grader citing tokens 0 to n-1 for every criterion. Under the audit framing that is honest (it is visibly lazy), but the agreement tool should report the share of judgements citing more than half the answer, so laziness is measured rather than hidden.

**What holds:**
- Deleting text matching (`Quote`, `_words`, `_bare`, the punctuation rules, the two-word minimum) is right; it removes the producer the two cage-match rounds kept finding holes in.
- Character offsets per token, so cited words display exactly as written, with no normalization anywhere.
- Keeping `ratingFor`, `Unanswered`, `GradingFailed` and the digest unchanged; the change is confined to evidence.

**If RECAST, what to fold back:**
- Reframe evidence as audit: state in "Producer first" that ranges make credit inspectable, and that the only defence against over-rating is the human-agreement measurement (task 22).
- An out-of-range or inverted range makes the grading `malformed` (fail closed), replacing "counts as unsupported".
- Tokenize by Unicode word boundaries, not whitespace; name the segmenter.
- The agreement tool reports how often a judgement cites more than half the answer.


## NoetherNullPointer's Design Strike

**Verdict:** RECAST

**Summary:** The design correctly restores one broken symmetry — the model can no longer *author* evidence — but it silently drops two conserved quantities the old mechanism also carried: `GraderVersion`'s claim to name the grading function, and `ratingFor`'s claim that a lengthened interval implies demonstrated recall.

**Producer first:**

Bad outcome: over-rating — a card scheduled after it has been forgotten because the rating said "recalled."

Producers of that outcome:

1. **`Quote.find`'s normalization and matching** let words the learner never wrote pass as theirs. This producer is *ours*, and the design deletes it correctly. `Span.of` makes the evidence a slice of the learner's own bytes; there is nothing left to match, so there is nothing left to match wrongly. This is the right move — delete the producer, don't sharpen the check. Accepted without reservation.
2. **The grader's judgement of meaning.** Untrusted model output crossing a trust boundary. Cannot be removed; the design says so and measures it with the agreement tool. Accepted.
3. **`ratingFor` in `assessment.dart` — not named as a producer, and left untouched.** `misconceived` caps at `hard`; `fraction >= 0.5` maps to `hard`; `hard` is a *passing* FSRS grade that lengthens the interval. A learner who meets half the rubric, or meets all of it while asserting a false claim, is scheduled forward. That is the design's own stated bad outcome, produced by our code, in one line, removable. The doc lists it as open question 3 and defers to Nick. "Nick's call" is a scheduling decision, not a reason the producer cannot be restructured. Under producer-first it must land in a findings bullet. It does.

The new check is `Span.of` — a bounds/existence test. Its producer (the model's index arithmetic) is not removable, so reviewing the check is legitimate. But note what changed underneath it: the check used to detect *fabrication* (text not in the answer); it now detects *counting* (index outside `0..n`). Same name, same consequence, different conserved quantity.

**Fatal flaws:**

- **Broken invariant: `GraderVersion` no longer identifies the grading function.** `PromptDigest` is SHA-256 over the system prompt and tool schema bytes; `GraderVersion = (prompt, model)`. The doc keeps it and says the digest "changes because the prompt does" — true, and insufficient. The grading function's output now also depends on two inputs that live in *code*, not in hashed bytes: the tokenizer (what "index 4" denotes) and the out-of-range policy (what happens when it denotes nothing). Change `split(RegExp(r'\s+'))` to split on punctuation, or change "out-of-range → missed" to "→ partial", and every receipt before and after carries the *same* `GraderVersion` while meaning something different — and the agreement tool pools them. The boast "any edit to either changes it without anyone remembering to" is now false for precisely the inputs this change introduces. CLASS: under-counted versioned surface / broken identity invariant.

- **Broken invariant: the two-word minimum was deleted on one of its two justifications.** The doc's reasoning is sound as far as it goes — the minimum existed to stop a *matching* accident, and there is no matching. But the minimum also bounded *evidence substance*, which the doc admits ("a single stopword is still lazy evidence") and then proposes to allow (open question 1). That re-admits the round-2 hole: "a one-word whole-answer exception that let one word support every criterion." The harm is conserved even though the mechanism rotated — from accidental match to deliberate lazy citation — and the harm is the design's own: one token cited for every criterion → all `met` → `ratingFor` → `good` → interval lengthened. The doc defers to the gold set, but the gold set measures *human agreement on judgements*, which is not the quantity at risk; a human can agree a token is related while the downstream rating is still inflated. CLASS: check deleted on one justification while a second still holds; the nominated measurement does not measure the harm.

- **Unstated assumption: evidence is contiguous and ordered.** The citation is `{start, end}` — an ordered interval — and the design never says why evidence must be contiguous or ordered. Order is the *source* of the failure the doc itself lists ("miscounted indices", off-by-one, "cite the neighbouring words"), and the remedy offered is a prompt tweak ("numbering each token explicitly"), not a restructure. Cite a *set of opaque per-token labels* (no arithmetic) and a near-miss stops existing to be mitigated: a wrong label is unambiguously wrong, not plausibly adjacent, and `start <= end` drops out of the invariant set entirely. CLASS: mitigation offered where the producer (ordinal addressing) could be deleted.

- **Under-specified value object: what does `Span` conserve?** `Quote` carried `text`. `Span.of(answer, start, end)` is described as the only constructor, and the doc promises evidence is "shown exactly as the learner wrote it" — but never says whether a `Span` holds the slice, the offsets, or both. Offsets only: `AssessmentReceipt` is not self-contained; no consumer can render evidence without being separately handed the answer, which the receipt does not carry. Text only: the offsets needed to *locate* the range are gone. The one object at the centre of the change has no stated state. CLASS: missing invariant on the central type.

- **Semantic drift under a stable name: `unsupportedCount`.** It counted "the grader cited text not in the answer" (fabrication). It now counts "the grader wrote an index outside `0..n`" (counting). The consequence is deliberately identical (criterion → missed; misconception → hidden, still caps), which hides the change. But index errors are a *common* model failure mode, so `misconceived` will now fire on clerical slips as often as on genuine ungrounded signals — every slip buying a `hard` where a `good` was earned. The direction is safe; the meaning of the counter has rotated, and anything reading it as a fabrication rate is now reading a different quantity. CLASS: blast-radius change masked by preserved consequence.

**What holds:**

- The core symmetry is restored *correctly*, and it is the producer-first move: the model cannot author evidence because evidence is a slice of the learner's bytes. `Span.of`'s private constructor makes fabricated evidence **unrepresentable** rather than detected. `Quote`, `_words`, `_bare`, the punctuation and bracket patterns, and every future round of holes in them are genuinely deleted, not patched.
- The rating stays outside the model's hands; the grader never picks it. Kept, correctly.
- `Unanswered`, `GradingFailed` and its causes, the fallback-to-self-rating path, and "exactly one valid judgement per criterion or it's malformed" are unchanged and sound.
- The doc's honesty about relevance is correct: no type can judge it, and pretending otherwise would be the same mistake in a new costume. Naming it as measurable-by-gold-set is the right disposition.
- Out-of-range → unsupported errs toward reviewing sooner, which is the safe direction for the stated harm.

**If RECAST, what to fold back:**

- Decide open question 3 *inside* the design, not beside it. Either change `ratingFor` so `misconceived` caps at `again` and sub-full credit is `again` — making "interval lengthened ⇒ recall demonstrated" a conserved invariant — or state the invariant the current mapping conserves and why it is the right one. The span change cannot deliver "no over-rating" while this producer stands.
- Extend `PromptDigest` to cover the tokenizer and the out-of-range policy (hash the tokenization rule's bytes alongside prompt and schema), so `GraderVersion` again names the whole function. State explicitly that a tokenizer change *is* a version change.
- Either restore a structural minimum (`Span.of` returns null unless `end > start`, so a single token cannot support a criterion), or state why one-token evidence cannot inflate the rating — and say plainly which quantity the gold set measures and which it does not.
- Specify `Span`'s fields: the token index range **and** the exact slice, so the receipt is self-contained and the UI can both render and locate the evidence.
- Consider replacing ordered indices with opaque per-token labels (a set, not a range): it deletes the off-by-one producer instead of mitigating it and removes `start <= end` from the invariant set. If contiguity is genuinely required for display, say so — that is the assumption currently unstated.

## CarnotCodeCarver's Design Strike

**Verdict:** RECAST

**Summary:** Delete quote matching; keep the span idea. Recast the model input so it preserves the answer’s meaning, and require evidence that indexing does not worsen grading. No real engine matches the Carnot cycle; a reviewer's job is to say how far short we are.

**Producer first:** The harm is false successful recall followed by an interval longer than the learner’s demonstrated recall warrants. The trigger is an erroneous grader response. Our producers are quote matching that accepts altered evidence, parseGrading converting accepted evidence into credited judgements, and ratingFor mapping those judgements into scheduling ratings. Spans remove the quote-matching producer. Semantic judgement remains necessary for automated assessment, so citation provenance cannot make false recall impossible. Bounds validation must remain because model-supplied indices cross a trust boundary. A further producer appears in this proposal: replacing the answer with whitespace-separated strings can discard meaning before grading. That producer can be removed by preserving the original answer as the authoritative input. The existing partial-credit-to-Hard policy is also ours; it is removable, but choosing its replacement requires the recall policy decision explicitly deferred by this design.

**Fatal flaws:**
- Make formatting-induced false recall impossible: preserve the original answer as the authoritative model input and derive citation annotations from that same immutable answer; then reconstruction from a whitespace-only list becomes unnecessary. The proposed list erases line breaks and indentation. For code, tables, and other structured answers, distinct answers can become identical inputs. Copying exact evidence afterward cannot recover meaning the grader never saw.
- The claimed boundary is too strong: an in-range citation proves source membership, not support. Selecting only 'correct' from 'not correct' can present authentic words while omitting the contradiction. The design acknowledges relevance and clipping, but 'cannot invent support' still treats provenance as a semantic guarantee. Removing the two-word minimum and changing the answer representation alters this failure surface; keeping the agreement tool unchanged does not establish that the change reduces the stated harm.
- The proposal leaves its decisive experiment unspecified. It asks the gold set to settle one-token evidence and indexing errors without specifying coverage or an acceptance decision. Aggregate rating agreement can conceal increased false successful recalls, especially when both partial credit and misconception caps still yield Hard. The design needs a comparison against the current assessor that measures the harmful direction of disagreement separately.

**What holds:**
- Extracting evidence from validated source coordinates deletes the normalization machinery and its recurring symbol-loss failures. Dijkstra: "Simplicity is prerequisite for reliability."
- Allowing one-token spans is reasonable: a single number or technical term can be complete evidence. A minimum length is a poor substitute for semantic judgement.
- Retaining bounds validation and conservative handling of unsupported criteria is justified. Untrusted coordinates still require interpretation.
- Separating evidence provenance from semantic judgement is sound, provided neither the documentation nor the evaluation conflates them.

**If RECAST, what to fold back:**
- Use one immutable answer representation containing the original text and derived token offsets. Generate both model annotations and displayed evidence from it. Specify whether indices are zero-based and inclusive; explicitly label tokens rather than relying on list-position counting.
- State the guarantee narrowly: displayed evidence is an exact source slice. Relevance, omitted negation, and contradictory context remain grader responsibilities.
- Before adoption, compare both assessors on human-labelled examples covering negation, symbols, repeated words, single-token answers, structured whitespace, and clipped citations. Report false successful recalls separately from overall agreement and set an acceptance criterion.
- Keep the Hard policy decision separate in implementation, but explicit in the safety claim: spans alone do not establish that the resulting schedule reflects demonstrated recall.


## Tesla, the Arc-Prophet's Design Strike

**Verdict:** RECAST

**Summary:** The fuzzy matcher dies, and a bare integer inherits the schedule: every in-range miscount rings the card as recalled and FSRS lengthens the interval.

**Producer first:** `Span.of` is a new check, and the unsupported-to-missed map and the hidden-misconception cap are kept checks. Over-rating (a criterion marked shown when it was not, so FSRS treats the card as recalled) has two producers on our side. The fuzzy quote match can be removed, and this design removes it. The producer installed in its place is `Span.of` turning any in-range pair into evidence that `CriterionJudgement.met` and `partial` credit: that can be made unable to produce credit by refusing to construct a `Span` unless the cited token strings equal that slice. Under-rating (the learner showed the criterion, a bad pointer becomes `missed`) is produced by the Design rule that an out-of-range citation is unsupported and the criterion becomes missed: that map can be deleted, and an unresolved pointer becomes `GradingFailed` plus retry. A failed misconception span still caps the rating through `unquotedMisconceptionCount` into `ratingFor`: that input can be deleted, so an unresolved misconception is absent from the receipt and the rating. A one-token stopword marked met is produced by a `Span` of length 1 allowed to build `CriterionJudgement.met` and a shown `Misconception`: the constructors can refuse that length. What no type can remove is the grader's reading of meaning once the slice is really those words; the gold set stays the measure, for criteria and for a misconception claim standing on a real slice. `ratingFor` turning a fraction of at least one half into `FsrsRating.hard` is a separate producer: a span cannot make half-credit unable to lengthen an FSRS interval, because only the meaning of "recalled" can, and half-credit can be a real memory. It is named here because this design changes how often it fires.

**Fatal flaws:**
- Make credited mis-address impossible: bind the citation to the exact token strings it names (or drop integers and accept only a token sequence that occurs once); then a bounds check stops being proof of support. Design, "What the grader returns" and "Miscounted indices": validity is `0 <= start <= end < tokenCount`. Models copy surface form faithfully and count badly. One-based indexes, exclusive ends, and a criterion index reused as a token index will drift. Drift that still lands inside the string becomes `met` or `partial` and a longer interval. The old `Quote.find` failed closed when the words were not there. An in-range wrong address fails open. "What this does not fix" calls the result neighbouring learner words and sends it to the agreement tool after the schedule has already moved.
- Make a whitespace split emit a citable void and a built-in off-by-one impossible. Design, "Tokens": "split on whitespace" with "no normalization anywhere" is the shape of `split` on `\s+`, which yields a leading empty token whenever the answer has leading whitespace, and a trailing one when it has a trailing newline. Text fields do both. The empty string is in range, so it can support `met`. A human who counts visible words is already one index off our array for the whole answer. State the token as a maximal non-empty run, with offsets into the original untrimmed answer.
- Make pointer failure record a learner miss impossible. Design, the `Span.of` paragraph: out of range "counts as unsupported, exactly as an unfound quote does today (criterion → missed)". That alias was built for a rare fabricated quote. Applied to ordinary index error it mass-produces `Again`, and `unsupportedCount` is diagnostic only — `ratingFor` already sees `missed`. The agreement tool is told to report clipping, which is an in-range short slice, so the rejected-pointer wave is invisible and looks like a stricter grader. An unresolved met or partial citation is `GradingFailed` and a retry.
- Make an unresolved misconception move FSRS impossible, and stop treating "the range exists" as grounding. Design, open question 2, keeps "no range: hidden, but still caps at Hard". The cap's producer is `misconceived: unquotedMisconceptionCount > 0`. A failed pointer is not a wrong claim. Meanwhile a resolved range became the cheapest predicate in the system: `{start, end}` on any tokens licenses a model-written claim shown to the learner. Existence of words is the unremovable-producer case for the claim's truth; it is removable for the schedule effect of a pointer that did not resolve.
- Make a one-token stopword unable to construct `CriterionJudgement.met` or a shown `Misconception`. Design, open question 1, allows it and waits for the gold set. The two-word floor's accidental-match reason is gone; its lazy-evidence reason is the over-rating producer. The gold set is off the scheduling path, so the producer runs until someone reads a report. The same cheapness makes `{start: 0, end: last}` on every criterion the laziest successful citation: two integers, reused, and the whole answer supports the whole rubric. Shared evidence can be legitimate, so this residual stays measured rather than banned — and it must be named as accepted residual, because the design currently describes it as deleted with the one-word exception.
- The stated harm and this change are coupled, and Design, open question 3, puts the coupling out of scope. `ratingFor` is unchanged. A fraction of at least one half becomes `FsrsRating.hard`, and Hard is a successful recall, so the interval still grows. Spans make in-range credit cheaper than a verbatim quote, so this path fires more often. Shipping the span while the rating rule stays put leaves "schedules it after it has been forgotten" intact for every partial and every capped full answer. The Again-versus-Hard choice belongs to Nick; the sentence that says the two do not interact does not survive.

**What holds:**
- The cage-match holes in [PR 183](https://github.com/enspyrco/engram/pull/183) were the matcher. Deleting `Quote`, `_words`, `_bare`, and the normalization patterns is the right deletion. Another patch on that match would hum at the same frequency.
- A private `Span.of` that copies from the learner's answer, keeps character offsets, and shows the original slice (case, punctuation, `!=`, `-5`) is sound. Symbols stay inside the token because nothing is stripped.
- An index into the learner token list cannot be the reference answer pasted back as a quote. That class of invented support is gone.
- `GraderVersion` still splits pools when the prompt digest changes. `Unanswered`, `GradingFailed` never thrown, and the grader still not choosing the rating all hold.
- Relevance of a real slice is correctly named as the grader's judgement. No span type can do that job. The gold set is the right instrument for it, once pointer faults are counted as grader faults beside it.

**If RECAST, what to fold back:**
- In Design, "What the grader returns": a citation carries the exact token strings for that range. `Span.of` returns null unless those strings equal the slice `tokens[start..end]` under raw string equality. Preferred simpler form: the model returns only those strings, copied from the shown list, and a span is built only when that sequence occurs once in the token list. Zero or several matches is an unresolved citation. Integers leave the interface, so off-by-one has nowhere to hide.
- An unresolved met or partial citation is `GradingFailure.malformed` (retry, then self-rating). It is not `CriterionVerdict.missed`. An unresolved misconception is dropped and does not set `misconceived`. Delete `unquotedMisconceptionCount` from the rating input.
- `CriterionJudgement.met` and `Misconception` require a span of two or more tokens. A one-token span may only build `partial`, or may build nothing; it may not build `met` and it may not be shown as a misconception. The gold set measures residual laziness on spans that already passed this floor. It is not the floor.
- Tokens are the maximal non-empty runs of non-whitespace in the original, untrimmed answer. Each token stores its start and end offsets. The receipt stores the captured substring `answer.substring(startOffset, endOffset)` taken inside `Span.of`. Later display uses that captured slice, so a future splitter change cannot move evidence under old indexes. The prompt digest covers the prompt and the tool schema; say in the design that a tokenizer change is a grader-version change too, because stored receipts and new splits would otherwise diverge.
- One number line in the prompt. Rubric identity stays `criterion_index` in the tool call. The token list is the only sequence the model counts. With token-text binding, a criterion index echoed as a span fails equality and becomes grader failure.
- Rewrite "What this does not fix" and open question 3 so the scheduling claim matches the mechanism: this design removes invented words, and it does not remove interval growth from `Hard`. State that partial credit and a misconception cap still lengthen the interval, and that cheaper in-range credit increases how often that happens. Leave Again-versus-Hard as Nick's decision, in the rating section, beside `ratingFor`, as part of this design's effect on the stated harm.
- Point the agreement tool at unresolved citations, token-text disagreements, identical full-answer spans repeated across criteria, and one-token partials. Clipping of an already accepted range is the smaller harmonic.
