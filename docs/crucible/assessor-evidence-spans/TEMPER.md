# TEMPER.md — assessor evidence as word ranges

**Overall verdict:** UN-TEMPERED (provisional) after the 3-round cap. Round 3: Maxwell SOUND; Noether, Carnot, Tesla RECAST. The core (exact citation of the learner's own tokens, no normalization, rating in code, failures never lengthen an interval) held all three rounds. Two round-3 findings reverse earlier folds (positions back in for repeated phrases; failed gradings must leave the due queue), so they are tradeoffs for Nick, listed under "Round 3 synthesis", not another strike.

**Round-by-round verdicts:** round 1 RECAST ×4 · round 2 RECAST ×4 · round 3 SOUND ×1, RECAST ×3.
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

Nick's decisions (2026-11-24): Hard only when nothing was missed; the over-rating threshold is set after the first run.

## Round 2 synthesis (dt-1795487997): RECAST, all four families

Deduped, most severe first:

1. **The grader is still asked to count.** Text binding guards a miscount instead of deleting it. — Noether, Tesla. DISPOSITION: fold. The grader returns copied token text only; engram finds the first contiguous whole-token run that equals it. No numbers in the grader's output, nothing to miscount.
2. **The fallback is itself an over-rating producer.** A failed grading fell back to self-rating, which can lengthen the interval and is invisible to the acceptance gate. — Noether, Tesla, Carnot. DISPOSITION: fold. A failed grading writes nothing to FSRS; the card stays due. Self-rating may be offered in the conversation, but it cannot move the schedule.
3. **The token-count rule changes grades and pushes graders to one-token partials.** — Carnot, Noether, Tesla. DISPOSITION: fold. Deleted; one token can fully meet a criterion or carry a misconception. Lazy one-token evidence reused across criteria is relevance, measured by the agreement tool (Tesla's residual, named).
4. **`tokenizerRevision` is a hand-bumped string.** — Maxwell, Noether. DISPOSITION: fold. The digest covers the tokenizer's pattern constant itself.
5. **The acceptance gate's population and policy are undefined.** — Carnot, Tesla, Maxwell. DISPOSITION: fold. Coverage (share of answers graded, not malformed) is reported with its own bar; over-rating is computed on graded answers, and malformed answers count as "no schedule change"; the gold set is split, the first part calibrates the threshold, which is then frozen and checked on the untouched second part. Reports name the rating policy.
6. **A misconception the grader can't cite.** — Noether, Tesla. DISPOSITION: resolved by 1 and 3 (copying one word always works). Tesla's "grader learns to emit none" is rejected: a grading call has no learning loop; misconception recall is measured on the gold set.

## Round 3 synthesis (dt-1795488407): Maxwell SOUND; Noether, Carnot, Tesla RECAST. Cap reached.

**Tradeoffs for Nick** (these reverse earlier folds, so a fourth strike would oscillate):

A. **Repeated phrases.** "Paris is wrong. Paris is correct.": copying `["Paris"]` cannot say which, and "first occurrence" can show a learner the clause they were rejecting. — Noether, Carnot, Tesla. Options: (i) the grader sends copied tokens plus a position, checked against each other, as round 1 had (Noether: "strictly stronger"); (ii) text only, and an ambiguous citation (several occurrences) is unresolved; (iii) keep every occurrence and show the ambiguity (Carnot).
B. **A card that can never be graded stays due forever.** — Noether, Tesla. Options: (i) a failed grading writes Again (it never lengthens the interval and the card leaves the queue; grader faults are still counted in coverage); (ii) per round 1 and Tesla, an unresolved met/partial becomes missed and an unresolved misconception still caps, and the rating is written; (iii) keep "no write" and end the item's turn so it returns next session.

**Folds without a decision** (agreed, small):
- The acceptance gate is keyed to `GraderVersion`: any version change (prompt, schema, tokenizer, model) needs the gate passed again before the new version writes to a schedule. — Noether, Tesla.
- The gate also bars under-rating, needs a stated minimum evaluation size, and checks coverage and errors together by answer type. — Tesla, Carnot.
- Gold-set labels are per-criterion judgements and misconceptions, rated under the same `RatingPolicy`. — Carnot.
- Remove the conversational "how did it go" question, or give its reply a type the FSRS write cannot accept. — Tesla.
- Name the remaining coverage risks: tokens with `"` or `\` arrive JSON-escaped; punctuation is glued to tokens (`capital.`). Raw equality (no case folding) stays. — Noether.
- The lazy-evidence detector also reports one-token citations, not only long or reused ones. — Tesla.

**Disputed, kept:** Noether argues all-partial → Hard has no floor. It is Nick's rating decision; recorded, not reopened.

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

---

# Round 2 — dt-1795487997

<!-- Arrival order, written as each returned. -->

## MaxwellMergeSlam's Design Strike

**Verdict:** RECAST

**Summary:** The folded design closes the fail-open miscount and makes grader faults fail closed, but it reintroduces the hand-bumped version string that round 1's digest existed to delete, now under the name `tokenizerRevision`.

**Producer first:** Bad outcome one: receipts from two different tokenizers pooled as one grader. Its producer is `tokenizerRevision`, a string a person must remember to change when the tokenizer changes. That is the same producer `PromptDigest` deleted for the prompt (Noether, PR 183 round 2). It can be removed: the tokenizer is defined by one pattern ("maximal non-empty runs of non-whitespace"), so hash the pattern constant itself into the digest, and an edit to the tokenizer changes the version with no one remembering. Bad outcome two: over-rating from a miscounted citation. Its producer, the bounds-only check, is made unable to produce credit by the text binding. That holds. Bad outcome three: relevance. It cannot be removed, and it is measured. That holds.

**Fatal flaws:**
- **A hand-maintained version input (DESIGN.md "Grader version").** `tokenizerRevision` is a string someone bumps by hand. A tokenizer edit without a bump pools receipts across two tokenizations: the exact failure the round-1 strike filed against the old `promptRevision`. Class: a check whose producer could be removed. Fold: the digest covers the tokenizer's pattern constant (and the token-joining rule, "single spaces"), not a revision label.
- **Unpriced liveness cost of fail-closed binding (DESIGN.md "Unresolved citations fail closed").** Raw string equality means a grader that writes a straight apostrophe where the learner typed a curly one, or a hyphen where they typed an en dash, fails the whole grading. That is the safe direction, but if it happens often, the grader is almost never usable, and the design doesn't say how that would be noticed or handled. Class: missing failure mode (degradation to zero coverage). Fold: the agreement tool reports the malformed rate, with the token pairs that failed equality, and the design names a coverage bar beside the over-rating threshold. Not a retry: a retry spends a second call to paper over the same copying fault.

**What holds:**
- Binding each citation to its exact text turns an in-range miscount from credit into a failed grading.
- Unresolved citations fail closed as grader faults; both unsupported counters and their rating input are deleted.
- The original answer goes to the grader unchanged, so line breaks and indentation reach it.
- The new rating rule makes "interval grows" require nothing missed and no misconception, which aligns the rule with the stated harm.
- The post-hoc threshold risk is named, with a commit-the-report-first mitigation.

**If RECAST, what to fold back:**
- Replace `tokenizerRevision` with the tokenizer's pattern constant and joining rule inside the digest.
- Add the malformed rate (with failing token pairs) to the agreement tool's report, and a coverage bar to "Acceptance before wiring".

## NoetherNullPointer's Design Strike

**Verdict:** RECAST

**Summary:** The design assumes a symmetry between two encodings of one citation — the grader's count (`start`/`end`) and the grader's copy (`text`) — and then, when the symmetry breaks (which the design itself predicts, "models count badly"), it pays for the break by handing the rating to the one rater the entire mechanism exists to distrust. That is the broken invariant, and it is load-bearing.

**Producer first:**

The harm: a card the learner did not demonstrate is rated as recalled; FSRS lengthens the interval; the fact is met after it was forgotten. Over-rating.

- **Producer 1 — grader writes evidence text the learner never wrote** (the old matching holes: `correct` inside `incorrect`, a lone stopword, `5` inside `-5`). **Removed.** No matching rule; evidence is copied from the token list. Its conduit is also deleted: `unsupportedCount` → "counts as missed" no longer exists, so the producer *and* the path that turned it into a rating are gone. Correct producer-first surgery.
- **Producer 2 — the grader miscounts a citation.** Not removed. The design **keeps the count in the protocol** and guards it with text-equality, then fails closed. This is a DEFECT (F1): the count can be deleted from the protocol entirely — the copied text alone locates the slice — and then the miscount is structurally unable to be produced and the guard becomes unnecessary.
- **Producer 3 — the grader's judgement of relevance.** Untrusted meaning-reading across a trust boundary; the harm *is* the input's meaning arriving, and only a meaning-reader can judge it. Cannot be removed; the design says so and measures it. Guard reviewed normally.
- **Producer 4 — the rating rule mapping half-credit to Hard.** Restructured by Nick's decision (Hard only when nothing was missed). Acceptable.
- **Producer 5 — self-rating on the failure path.** OURS, and **the producer table omits it.** "The caller falls back to self-rating" is stated and never analysed, yet self-rating is the producer the blind assessor was built to replace. This is a DEFECT (F2).

**Fatal flaws:**

- **F1 — the count is kept, then guarded, instead of deleted (producer not made impossible; guard where deletion belongs).** `DESIGN.md` "What the grader returns" / "`Span`": the citation carries `start`/`end` *and* the copied text, and resolves only when they agree. The design's own premise is "models copy text well and count badly," so the guard fires exactly on the failure the design predicts. The count is not needed to express the citation: a copied run matched against contiguous **whole-token** runs of the answer names the same slice, cannot miscount, and keeps every guarantee the design states. Keeping the count manufactures the failure; the text-equality check is then a hole in a guard, not a guard.
- **F2 — the fallback is the producer (under-counted blast radius; wrong option-frame).** One unresolvable citation among N criteria discards all N judgements — including a misconception the grader *did* see — and routes to self-rating. Self-rating over-rates; that is the premise of the whole feature. The design frames the choice as "penalize the learner for a grader fault vs. not," but the axis that matters is "which failure direction over-rates," and it chose the one that does. Worse: the acceptance gate measures "over-rating (grader higher than the person)" — self-rating is not the grader, so this over-rating is **invisible to the gate that is supposed to catch over-rating.**
- **F3 — the conservative signal was deleted (missing failure mode; safety signal replaced in the unsafe direction).** `unquotedMisconceptionCount` "still cap[s] the rating… err[s] toward reviewing the card sooner." Deleted; `misconceived` is now true only for a *resolvable* misconception. A grader that sees a wrong claim but cannot cite it (see F4) now routes the whole grading to self-rating instead of capping at Hard. The Rating section's promise — "a confidently wrong claim now brings the card back soon" — holds only when the claim is cited in two or more resolvable tokens.
- **F4 — the length rule's enforcement point is unspecified, and one-token misconceptions are unrepresentable (type cannot hold a state the domain has).** "`met` and `Misconception` require a span of two or more tokens. A one-token span may support `partial` only." The design does not say whether a one-token `met` citation is *invalid* (→ fail closed → self-rating) or *downgraded* (→ Hard). For short answers — "Yes", "4", "Paris", the common case — those differ by a full fallback. And a one-token misconception **cannot be constructed at all**, so an honest grader citing the wrong claim in a one-token answer ("Yes" to "is the earth flat?") emits a malformed grading → self-rating. Length is a proxy for evidence, not evidence: two tokens "it is" earn `met`; one token "42" cannot.
- **F5 — `tokenizerRevision` is remembered, not derived (invariant asserted, not conserved).** `PromptDigest`'s stated property is "derived from their bytes, so any edit to either changes it without anyone remembering to." The `tokenizerRevision` is a hand-maintained string inside the digest. A tokenizer edit that forgets the bump leaves the digest unchanged and pools receipts from two tokenizations in the agreement tool. The conserved quantity "one digest ⇔ one grader behaviour" leaks on the tokenizer half.

**What holds:**

- Producer 1 is removed cleanly: no normalization, no punctuation stripping, no word-splitting — whole-token citation makes `correct` unfindable inside `incorrect` and `5` unfindable inside `-5`. The conduit (`unsupportedCount`) dies with it. This is the right surgery.
- "Displayed evidence is an exact slice of the learner's answer" is the right invariant to want, and the design states its limit honestly: it does not guarantee the slice shows the criterion.
- Separating `criterion_index` from the token sequence is correct; the token list being "the only sequence the model counts in" is the right separation — the mistake is making it count at all.
- Storing the captured substring in the receipt so old receipts never move under a tokenizer change: right.
- The Rating change conserves the right quantity: partial credit no longer buys a lengthened interval.
- Acceptance before wiring, first-run report committed before the threshold, over-rating measured separately from overall agreement, relevance measured rather than guarded with the reason stated.

**If RECAST, what to fold back:**

- Delete `start`/`end` from the grader's citation. The grader returns the copied token run only; `Span.of(answer, text)` finds it as a contiguous run of **whole tokens** and computes character offsets at parse time. A miscount then cannot exist, and the fail-closed rule for it becomes unnecessary — not better-guarded, unnecessary.
- If indices are kept for any reason, they are a *hint*: on disagreement the text wins (the design says the text is what models get right), and the disagreement is recorded for the agreement tool, never fatal.
- Malformed must never fall back to self-rating. Retry the grader inside the existing `maxRetries` budget (the design currently spends it on the rare failure — network — and none on the predicted one — miscount), then produce the conservative outcome: the card comes back sooner. Reinstate conservative treatment of an unverified misconception.
- Make the length rule's enforcement explicit: a one-token citation for `met` downgrades to `partial` (never fails the grading); make a one-token misconception representable, or state that it caps at `Again`.
- Derive `tokenizerRevision` from the tokenizer's own artifact rather than a hand-written string, so the digest keeps its "no one has to remember" property.
- The acceptance report must include the malformed rate **and** the over-rating of the fallback path, or the gate is measuring only the grader while the deployed system over-rates around it.

## CarnotCodeCarver's Design Strike

**Verdict:** RECAST

**Summary:** Exact spans improve provenance, but whitespace still controls semantic credit and the acceptance gate can be fitted to its results. No real engine matches the Carnot cycle; a reviewer's job is to say how far short we are. Here, evidence integrity improves while grading reliability remains unproven.

**Producer first:** Bad outcome: the learner receives a successful-recall rating without demonstrating the required knowledge, delaying review. The trigger is an incorrect model judgement; our producers are the parser admitting that judgement and ratingFor converting it into Good or Hard. Exact citations cannot make this impossible: selecting genuine words does not establish their meaning. Semantic judgement must remain if automated assessment remains the feature. A separate harm is downgrading a complete answer solely because it occupies one token. Its producer is our two-token eligibility rule, which can be deleted. Finally, malformed output triggers self-rating: this prevents an automated receipt, but does not itself prevent an excessive scheduling interval. That fallback preserves manual review and must be assessed as a separate outcome.

**Fatal flaws:**
- Make whitespace-dependent eligibility impossible: remove token-count requirements from met judgements and misconceptions; then the two-token eligibility checks become unnecessary. A criterion inside a multi-criterion rubric can be fully answered by one number, formula, or name. Calling that partial changes the assessment rather than preserving it. A one-token wrong claim also needs to be representable. The acknowledged script limitation therefore changes grading outcomes, not merely audit quality.
- The acceptance gate has no independent acceptance evidence. Choosing the threshold after inspecting the same results permits an arbitrary pass; committing the report preserves the history but does not remove that selection bias. Use the first run for calibration, then freeze the threshold and evaluate on untouched human-rated examples before schedule wiring.
- The acceptance population is unspecified. Malformed citations divert answers to self-rating, so agreement calculated only on successful receipts can improve by excluding difficult answers. Reporting malformed counts separately does not establish acceptable coverage or scheduling behavior. Define the denominator, minimum coverage, and treatment of fallbacks before the acceptance run.
- Evaluation identity omits a component that directly produces the harm: ratingFor. Its policy changes in this design, yet GraderVersion identifies only prompt, schema, tokenizer, and model. Identical criterion judgements can therefore produce different ratings under one recorded grader version. Preserve raw judgements and identify the rating policy used for every reported scheduling comparison.

**What holds:**
- Constructing displayed evidence from the immutable answer removes invented quotations and normalization-based false matches.
- Checking both token coordinates and exact token text rejects miscounts that land on different text. It does not detect every wrong coordinate when identical text repeats.
- Rejecting the whole malformed grading avoids quietly converting grader citation errors into learner misses.
- The revised rating policy closes the explicit paths from missed criteria or recorded misconceptions to Hard.
- The design correctly limits its guarantee to provenance and leaves semantic relevance to empirical evaluation.

**If RECAST, what to fold back:**
- Keep spans as provenance and remove token length as a semantic eligibility rule. Dijkstra: "Simplicity is prerequisite for reliability." The unnecessary machinery is the attempt to infer evidential sufficiency from whitespace.
- Use the first report to develop the grader and acceptance criteria. Require a subsequent untouched evaluation with frozen over-rating and coverage requirements; report uncertainty and results by answer length and script.
- Report the complete outcome distribution: automated receipts, malformed results, other failures, and manual fallbacks. Describe self-rating as a manual handoff, rather than an end-to-end fail-closed scheduling guarantee.
- Version the rating policy alongside grader inputs, and record the evaluation dataset and human-label revision so acceptance results remain reproducible.
- Specify that all spans in a receipt belong to the same answer. Captured substrings preserve display, but answer identity and tokenizer revision are needed if stored coordinates will later be audited.


## Tesla, the Arc-Prophet's Design Strike

**Verdict:** RECAST

Tesla: "If you want the secrets of the universe, think in energy, frequency and vibration."

**Summary:** The citation type is true, and the protocol still asks the model to count — the one motion this design says the model loses — so at steady state the grades that survive are the easy one-token partials, Hard lengthens the interval, and every miscount falls through to self-rating, which the acceptance gate is built not to hear.

**Producer first:** The harm is a card scheduled as recalled after the learner did not show it. Four checks, four producers.

1. `Span.of` refuses an in-bounds index unless the supplied `text` equals tokens `i..j` joined by single spaces (Design, `Span`; Producer first §2). The producer is ours: the return shape asks the grader to emit `start` and `end`, and a later reader treats a resolved span as credit. A miscount can be made unable to exist by taking indices off the model's output. The model copies token text from the numbered list; only the program locates the unique contiguous range whose join equals that text. Zero matches or more than one and the citation does not resolve. The index-equality check then has nothing to guard.

2. The two-token floor on `met` and `Misconception`, with one token allowed only for `partial` (Design, Lengths). The producer of the original matching hole "one word supports every criterion" is the rating rule counting each partial as its own credit. That floor leaves the producer in place: the same one-token span, repeated once per criterion, is a legal receipt and rates Hard, and Hard is a successful recall. Make a success rating unable to come from a union of evidence that is a single token; the length floor is then a display rule, and it stops being the guard.

3. Any citation that does not resolve burns the whole grading to `GradingFailure.malformed`, and the caller self-rates (Design, Unresolved citations fail closed). The producer of over-rating on that path is the fallback writing a learner-chosen success into FSRS. The trigger is a bad citation. The schedule write is ours. Make an interval increase impossible from anything except a resolved receipt; self-rating can remain a UI conversation and still be unable to lengthen a card. Fail-closed stays as "no receipt." It stops being a door onto the schedule.

4. The agreement gate withholds wiring until an over-rating threshold is passed, and the number is chosen after the first run (Design, Acceptance before wiring). The producer is the wiring step treating "resolved receipts look calm" as "the schedule will be calm." The numerator can be fixed now so unresolved grades count as the rating the schedule will actually apply. A threshold chosen afterward can still be honest only if that definition is already closed.

Producer 3 in the design, the semantic judgement, stays. A reader of meaning is the feature. Nothing above replaces it.

**Fatal flaws:**
- Make a miscounted citation unable to touch the schedule: the grader returns copied token text only, and `Span` is born only from a unique program-side location in the token list; then model-emitted `start`/`end` and the index-equality check become unnecessary. As written, the grader still returns inclusive indices (Design, What the grader returns) while Producer first §2 states that models count badly and copy well. Inclusive ends are the native off-by-one of every model trained on half-open slices. Each of those vibrations is specified to destroy the entire grading, and the caller falls back to self-rating. Self-rating is allowed to mark a successful recall. The old `Quote` path turned a bad citation into a miss and the card came back; this fold turns the same fault into the learner's hand on the interval. The third consequence sits one octave up: a two-token `met` is easy to miscount and dies, a one-token `partial` is the easiest equality there is (`start == end`, copy one list item), and the Lengths rule teaches the grader, by rejection, to speak only in one-token partials.
- Those surviving receipts rate Hard whenever nothing is marked missed (Design, Rating), and Hard lengthens the FSRS interval. One token attached to every criterion is a full success-shaped receipt. A spaceless answer is the same chord played on one string: Chinese, Japanese, Thai, a URL, a single code blob is one token (Design, Named tradeoff), so a `met` or a misconception cannot resolve at all, and the only receipt that both resolves and advances the card is every criterion `partial` on that lone run. The tradeoff calls this "weak evidence" and "audit little." Under Lengths plus Rating it is a Hard, or a malformed grading routed to self-rating. The segmenter is described as a later mitigation; until it exists those answers still move the schedule.
- The acceptance instrument listens to the wrong frequency (Design, Acceptance before wiring). It reports over-rating on grader-versus-human judgements, and reports unresolved citations beside that number. Production will schedule the fallback, and the threshold is written down after the report exists. A numerator that excludes malformed grades will look like agreement exactly when the live path is self-rating. The commit-the-report mitigation freezes the table and leaves the definition of "over-rating" free. The same gap sits in the version: the digest covers the prompt, the tool schema, and `tokenizerRevision`, and `ratingFor` stays a live derivation, as it is on `AssessmentReceipt.rating` today. A later edit to the rating rule moves every old receipt's meaning, and the threshold commit still cites a report from the previous mapping.
- A misconception counts only when a two-token span resolves, and a citation that fails takes the whole receipt with it (Design, Producer first §4's deletion of `unquotedMisconceptionCount`; Unresolved citations fail closed). The durable strategy is to emit no misconception. A wrong claim then leaves Good available whenever the criteria were cited cleanly. The old unquoted count erred toward reviewing sooner. This design deletes that input and keeps "no misconception" as the condition for Good.

**What holds:**
- Fuzzy matching is actually gone. No case folding, no punctuation strip, no `correct` inside `incorrect`, no `5` inside `-5`. Evidence text is copied from the answer's own tokens. That deletion is the ore and it is sound.
- A `Span` that stores `answer.substring(startOffset, endOffset)` plus the offsets is a receipt that stays still when the tokenizer later changes. Putting `tokenizerRevision` in the digest keeps old and new grades out of one agreement pool.
- The new `ratingFor` map is the right coupling for the stated harm wherever a receipt is real: a miss is Again, a misconception is Again, half credit is no longer a success, Easy is never offered. Nick's decision is recorded in Rating and belongs there.
- Relevance of a true slice stays outside the type, measured by the human-rated set. That refusal to invent a semantic checker is correct.
- Fail-closed as "a bad citation is a grader fault" is the right instinct. Its blast radius is what has to be folded, and the instinct stays.

**If RECAST, what to fold back:**
- In **What the grader returns** and **`Span`**, delete model-emitted `start` and `end`. The tool returns `text` copied from the numbered token list, the space-join of a contiguous range. `Span.resolve(answer, text)` is the only constructor: it finds every contiguous token range with that join. One match builds a span carrying the token range, the original character offsets, and `answer.substring(startOffset, endOffset)`. Zero or many matches do not resolve. Say in the same paragraph that a `met`, a `partial`, or a misconception that omits `text` is the same failure as a text that does not resolve, and that `missed` carries no span. Credit without a `Span` is unrepresentable.
- In **Unresolved citations fail closed**, specify the schedule effect: `GradingFailed` cannot advance an FSRS interval. The UI may still ask the learner what they think. That answer is not a success rating. The card waits, or it is written as Again. Name this as deleting the producer, not as a stricter threshold.
- In **Lengths** and **Rating**, add one rule to `ratingFor`: Good and Hard require a resolved span per credited criterion, and the union of those spans is at least two tokens. The same range repeated across criteria credits once; the other criteria are missed for scheduling. One token can still display as a `partial` and can still be stored on the receipt. It cannot, alone, lengthen an interval. Keep Nick's map otherwise: any miss or any resolved misconception is Again; all met and no misconception is Good; mixed met/partial with a union of two or more tokens and no misconception is Hard.
- In **Named tradeoff**, replace "audit little" with the consequence of the rules above: a one-token answer cannot receive a success rating until a segmenter splits it. Until then it takes the no-advance path. The agreement tool's per-answer token counts remain the signal that says whether the segmenter is due.
- In **Grader version** and **Acceptance before wiring**, fold the rating rule into the version (digest the source of `ratingFor`, or store the `FsrsRating` applied at grade time on the receipt). Fix the over-rating numerator before any run: a grading that will not advance is not an over-rate; a grading whose failure path would let the learner write a success counts as an over-rate. Nick still chooses the numeric threshold after the first committed report. He chooses it against that numerator, and the threshold commit cites the report by that definition.

---

# Round 3 — dt-1795488407

<!-- Arrival order, written as each returned. -->

## MaxwellMergeSlam's Design Strike

**Verdict:** SOUND

**Summary:** With positions gone from the grader's output and failed gradings unable to touch the schedule, every producer of over-rating that is ours is removed, and the one that isn't (relevance) is measured before wiring.

**Producer first:** Over-rating's producers: fuzzy matching (removed: exact whole-token equality), counting (removed: the grader returns no numbers), a fallback that can lengthen an interval (removed: `GradingFailed` writes nothing to FSRS), and a rating rule that counted partial answers as recalled (restructured by Nick's decision). The remaining producer is the grader's reading of meaning, which cannot be removed because it is the feature; the design measures it on a split gold set with a frozen threshold. No check in this design guards an outcome a restructure could delete.

**Fatal flaws:**
- none

**What holds:**
- `Span.find` locates copied tokens by raw equality; there is nothing to normalize and nothing to count, so the two hole-producing mechanisms of PR 183 are gone rather than patched.
- A failed grading is "no review": it cannot over-rate, and coverage is measured with its own bar so a grader that fails often is visible.
- The digest covers the tokenizer pattern, and receipts store judgements with a named rating policy, so a changed tokenizer or policy can't masquerade as the same grader.
- The calibration/evaluation split answers the post-hoc threshold risk.

**If RECAST, what to fold back:**
- (not RECAST) Two notes for the build, neither a design flaw: say that a failed grading ends that item's turn in the conversation and the card returns next session, so a systematically failing item can't loop within one session; and display evidence as "first occurrence" so a reviewer of a repeated phrase knows the highlight may be the earlier one.

## NoetherNullPointer's Design Strike

**Verdict:** RECAST

**Summary:** The conserved quantities claimed here are "the receipt locates the slice the grader actually cited" and "every card leaves the due queue"; the first is conserved only up to the *first* occurrence, and the second is not conserved at all — and the rating policy quietly reintroduces the very over-rating the whole design exists to kill.

**Producer first:**

- *Over-rating from words the learner never wrote.* Producer: the normalization pipeline (`Quote._words`/`_bare`: case fold, quote/bracket strip, trailing-punctuation strip) turning near-misses into matches. **Deleted.** Raw whole-token equality has no rule left to have holes in. Correct, and it survives my strike.
- *Over-rating from mis-counted positions.* Producer: any protocol that asks the grader for positions. Deleted — but see Flaw 1: the replacement re-derives location by inverse search, which is the same producer wearing a different hat.
- *A failed grading lengthening the interval.* Producer: the self-rating fallback's write to the schedule. **Deleted**, and at the type level it stays deleted (`GradingFailed`/`Unanswered` carry no rating and no receipt). But the replacement creates a new producer: unbounded deferral (Flaw 2).
- *Relevance (producer 5).* Cannot be removed: only a reader of meaning can judge it, and the harm is the judgement itself arriving across a trust boundary. I review its check (the agreement tool) normally — and it is leaky (Flaws 3, 5).
- *A gate-passed grader writing to the schedule.* Producer: our process — gate runs once, thresholds frozen, nothing binds them to the version. Restructurable into a capability (Flaw 4).

**Fatal flaws:**

- **Broken invariant (location is re-derived, not conserved).** `Span.find` resolves a copied token run to *the first place it occurs*. That map is the inverse of the tokenizer and is not injective. The doc dismisses this — "the credit is the same wherever they occur" — but the receipt is the audit artifact and misconception evidence is *displayed to the learner*. When the same consecutive run appears twice and one occurrence is quoted, reported, or inside a denial, the receipt points at the wrong one; a misconception citation can accuse the learner of words they were quoting in order to reject. The design's reason for deleting positions does not survive its own copy: the copied token *is* a checksum, so `{"i": int, "t": str}` — index plus copy, verified — is strictly stronger than either alone. A miscount becomes detectable instead of silently becoming wrong credit, and repeated phrases stop being ambiguous.
- **Missing failure mode / under-counted blast radius (the card can never be cleared).** "If any citation does not resolve … the outcome is `GradingFailed`" plus "A `GradingFailed` never writes to FSRS: the card stays due and comes back." One transcription slip — a dropped comma in `capital.`, a case flip, a JSON-escaped `"` inside a token — discards *all* the judgements that resolved fine and strands the card in the due queue with no stated terminal state. Producer is ours: "a partial grading is no grading." Against the stated harm it buys nothing, because raw whole-token equality already makes an unresolved citation unable to manufacture credit. Wrong option-frame: the invariant you need is *a failure never lengthens the interval*; *a failure writes nothing* is stronger and leaks liveness instead.
- **Reintroduced producer (the policy is unbounded in partials).** "Hard: no criterion missed, at least one only partial, no misconception." There is no floor. The interval lengthens whenever the grader declines to say `missed` — and `missed` is the *only* verdict carrying no evidence and admitting no check, while `partial` is satisfiable by one copied token. All downward pressure is unverifiable; all upward pressure is cheap. An agreeable grader returns all-partial → Hard → interval grows, which is the design's own bad outcome reproduced at the one layer neither derived from evidence nor covered by the digest. The old `ratingFor` had a ≥0.5 floor; the restructure removed it.
- **Coupling that should be removed (the gate is not conserved by the digest).** The digest covers prompt, schema and tokenizer bytes — good — but the rating policy is "a named `RatingPolicy`", i.e. exactly the hand-kept version constant the digest deleted for the prompt. And nothing binds the gate to the version: edit the system prompt, the digest changes, and a grader that never passed the gate writes to the schedule. Relevance is "measured, not guarded", so the gate is the *only* thing between an over-rating grader and FSRS; its validity must be structural, not remembered.
- **Under-counted blast radius (unnamed coverage producers).** Named tradeoffs list only scripts-without-spaces and code blobs. Unnamed, and each now fatal to a whole grading: case sensitivity (an over-correction — `_bare`'s hole was bracket/punctuation *stripping*, which made `-5` match `5`; case folding has no word-boundary hole), punctuation glued to tokens (`capital.`), and tokens containing `"` or `\` arriving JSON-escaped in the very list the grader is told to copy from. The gold set contains no CJK answer, so the coverage bar passes over precisely the blast radius the design admits to.

**What holds:**

- Deleting the normalization pipeline: real, and the only hole-free way to kill producer 1.
- Deleting the self-rating write: real, and structurally enforced — no rating field exists on the failure types. Keep it that way; delete "the conversation may still ask the learner how it went" or make the discard visible, since a rating collected and silently dropped is a deceptive affordance.
- `Span`'s private constructor, built only by `Span.find`: the right shape for the guarantee it can actually make — a receipt cannot contain text the learner did not write. It conserves *"the slice is the learner's"* and nothing more; the doc should stop implying it conserves *"the slice is the cited one"*.
- The derived prompt/schema/tokenizer digest, for the producer it names.
- Coverage and over-rating measured on a held-out split, with failed items counted as "no schedule change", is the correct accounting for the primary harm.
- The one-token/no-length rule and the all-or-nothing "no schedule write" are the right *direction*; they are just over-rotated (Flaws 2, 5).

**If RECAST, what to fold back:**

- Grader returns `{"i": index, "t": token}` per citation; engram verifies `tokens[i]` against `t` (case-folded) and builds the `Span` from `i`. Location becomes exact, the repeated-phrase caveat and "credit is the same wherever" both disappear, and the reused-citation detector gets a real key (compare resolved spans, not citation strings — overlapping citations currently slip past it).
- Resolve per citation: an unresolved citation can make a criterion `missed`, never `met`; the rest of the grading stands. If you keep whole-grading failure, state the terminal behavior for a card that fails N times — silence is not a schedule policy.
- Give the policy a floor over the `met` count (or make `partial` insufficient for Hard alone), and digest the policy source alongside the prompt so a policy edit changes the version.
- Make the FSRS write take a gate-passed `graderVersion`: a grader that has not passed the frozen gate cannot write, by capability rather than by memory.
- State the real equality strictness: case-folded whole-token equality (no stripping), how a token containing `"`/`\` is expected to be copied, and add the named weak classes (no-space scripts, code blobs, URLs) to the calibration split so the coverage bar can see them.
- Delete "the conversation may still ask the learner how it went" or mark the discard in the UI.

## CarnotCodeCarver's Design Strike

**Verdict:** RECAST

**Summary:** Exact token copying removes normalization machinery, but arbitrary occurrence selection corrupts evidence attribution, and the acceptance gate does not yet establish dependable scheduling safety. No real engine matches the Carnot cycle; a reviewer's job is to say how far short we are.

**Producer first:** The harm is crediting recall the learner did not demonstrate, then postponing review. Malformed output and misleading quotations are triggers; our producers are the judgement-to-rating policy and the caller that writes that rating to FSRS. Deleting the self-rating fallback write removes one producer structurally. Semantic judgement cannot be removed while retaining automatic assessment, so citation validation must be reviewed as a provenance check, not a correctness check. A separate producer is Span.find choosing the first occurrence: our locator turns ambiguous copied words into a falsely specific evidence attribution. That producer can be removed.

**Fatal flaws:**
- Make falsely specific evidence attribution impossible: represent every matching occurrence and retain ambiguity; then first-occurrence selection becomes unnecessary. “The credit is the same wherever they occur” confuses a global judgement with local evidence. In “Paris is wrong. Paris is correct.”, copying ["Paris"] cannot identify which assertion supports the judgement. Choosing the first occurrence manufactures that identification.
- The evaluation contract does not require human labels to use RatingPolicy.nothingMissed. A gold set rated under the previous half-credit policy can validate the wrong behavior, especially around partial recall and misconceptions. Freeze human criterion judgements and misconception labels, derive comparable ratings under the named policy, and adjudicate disagreements before treating agreement as scheduling evidence.
- The release gate specifies point estimates without evaluation size or uncertainty. A small held-out set can pass an over-rating threshold despite providing little evidence about the true error rate. Conditional over-rating also conceals selective grading failures unless coverage and errors are examined together across relevant answer types. Freeze the sampling unit, minimum evidential strength, and joint acceptance calculation before evaluation.

**What holds:**
- Exact token equality and source offsets remove the normalization rules that previously manufactured matches. The narrow guarantee is stated honestly.
- Deleting the failed-grading schedule write removes dangerous fallback behavior instead of adding another guard.
- Keeping scheduling policy outside the model and naming it in reports makes policy changes inspectable.
- Semantic relevance remains an unavoidable model judgement. Requiring exact evidence cannot establish entailment; the design correctly acknowledges that boundary.
- Dijkstra: "Simplicity is prerequisite for reliability." Deleting punctuation repair, minimum quote length, and unsupported-evidence counters reduces machinery and maintenance entropy.

**If RECAST, what to fold back:**
- Replace first-match Span semantics with an occurrence set tied to the immutable answer. Display ambiguity explicitly; resolve meaning using the answer's context.
- Specify gold-label provenance and derive both human and model ratings through the same frozen RatingPolicy.
- Commit an evaluation protocol that accounts for sample size, uncertainty, grading failures, and relevant answer groups before opening the held-out results.
- Retain exact copying and the no-write failure outcome. These are useful reductions in irreversible scheduling harm; do not rebuild fuzzy matching around them.


## Tesla, the Arc-Prophet's Design Strike

**Verdict:** RECAST

**Summary:** Exact token equality is the true string, and the gate is tuned to the wrong harmonic: one unresolved citation pins the card at "due now" forever, while an over-rating-only bar scores that silence as safety.

**Producer first:** Three guards are in this design. (1) Any unresolved citation, missing tool call, or malformed call becomes `GradingFailed` and writes nothing to FSRS (Design, "Failed gradings"). The harm of a missing or malformed call is an interval that moves when the grader produced no judgements. The producer is a parser willing to complete a receipt from an absent tool call. That producer is already gone if `Graded` can be built only from one verdict per criterion, so a no-write failure stays for transport, absence, and malformed shape: there is no judgement there to turn into a rating. The harm of an unresolved citation is different: a met or partial whose words are not in the answer still lengthens the interval. The producer is a successful verdict that exists without a resolved `Span`. Delete that producer. A met or partial with no `Span` is a miss; a misconception attempt with no `Span` still sets `misconceived` and is not shown. The policy then writes Good, Hard, or Again, and the card leaves "due now." The total refusal is unnecessary once those types cannot carry a fake success. (2) The conversation may still ask how it went, disarmed only by the sentence that the answer cannot move the schedule (same section). The harm is a self-assessment marking a forgotten card as recalled. The producer is that question's reply, still shaped like a rating a later call site can write. Delete the question, or give the reply a type the scheduler cannot accept. The sentence then has nothing to guard. (3) Wiring waits on an over-rating threshold and a coverage bar (Acceptance before wiring). The harm is a forgotten card scheduled as recalled. The producer is the grader's reading of meaning (producer 5). It cannot be removed: only a reader of meaning can tell whether a real token shows a criterion, and exact equality does not decide that. The gate stays, and it is struck below because it counts one axis. The Hard restructure does remove a producer: the old half-credit path that turned missed criteria into an FSRS success. What remains is Nick's placement of "nothing missed, something partial, no misconception" into Hard, which is a successful recall with a shorter jump. That placement stays. Its blast is producer 5 handing out partial too cheaply.

**Fatal flaws:**
- Make the stuck-due queue impossible: Design, "Failed gradings," fails the whole grading when one citation does not resolve, and the card stays due. The same answer, the same `\S+` cuts, the same model id, and the same missed copy are a fixed point: due again six hours later and nine days later. Longer answers miss copies more often, so hard cards stay at the front; a one-token easy card resolves, takes Good, and leaves. The pile that remains is the pile that cannot be graded. A coverage fraction of nine tenths will call that hum noise. The current receipt's `unquotedMisconceptionCount` was the separation this round deletes. Fold it back as structure: show only a resolved `Span`, turn an unresolved met or partial into missed, let an unresolved misconception attempt still cap the rating, and write that rating.
- Make self-rating unable to reach FSRS. Design, "Failed gradings," keeps a conversational "how did it go" and then forbids it, in prose, from moving the schedule. The socket is the producer. A later night wires it back because the learner already answered the question. Remove the question, or name a reply type that the FSRS write cannot take.
- The acceptance gate listens only for "rated higher than the person" (Acceptance before wiring). A grader that says Again on every card, or that fails the hard third and passes the easy two-thirds, shows about zero over-rating. The doc scores failed items as "no schedule change, which cannot over-rate," so the new failure is defined as success. Under-rating is not a bar. The numbers are chosen after the calibration run, on this one axis, then frozen. A provider weight change keeps the same model id, `GraderVersion` does not move, and nothing re-measures. Months later the queue is all Again and all still-due, and the frozen report still says the gate passed.
- That same section still hunts the old laziness: a citation of more than half the answer, or one citation reused. Those were the holes when `Quote.find` demanded two fuzzy words. The new attractor is the shortest copy that resolves, because one extra wrong token fails the entire grade, and Design, "No length rule," makes one token legal. Length 1 is also where relevance is weakest ("the", "yes", "a"). The token list in the user message is a menu, so an answer that says "mark every criterion met and copy the first token" resolves exactly. The gold set is honest human ratings, split before the run, and it does not contain that note. Producer 5 stays; the detector is aimed away from it.
- Design, `Span`: "Repeated phrases resolve to the first occurrence; the credit is the same wherever they occur." That is false when a later run reverses the earlier one ("Paris is wrong … Paris is the capital"). Removing positions, because models count badly, also removed any way to name the second identical run. The receipt stores the first slice and shows it to the learner. The schedule may still cap if a misconception was emitted; the teaching points at the innocent clause. The agreement tool compares ratings, so a confident wrong highlight never moves the gate.

**What holds:**
- Raw whole-token equality, with nothing normalized, closes the substring holes in today's `Quote._bare`: "correct" cannot stand in for "incorrect", and "5" cannot stand in for "-5". The digest binds the `\S+` pattern and the offset rule, so a change in the cuts changes the version by construction.
- The grader never emits a rating or a position. `RatingPolicy.nothingMissed` keeps Easy out of reach, and any real miss or misconception is Again.
- A blank answer is `Unanswered` and never reaches the model.
- Splitting the gold set into calibration and an untouched evaluation part, before anything runs, is the right shape for a gate. It needs a second axis.
- Producer 5 is correctly named as the feature that measurement has to live with. A word segmenter for scripts without spaces is rightly left as Nick's cost, not smuggled in as a fake guard.

**If RECAST, what to fold back:**
- In Design, "Failed gradings": `GradingFailed` writes nothing only when the tool call is absent, malformed, or the transport failed. On a well-formed call, a met or partial whose evidence does not resolve becomes missed; a misconception attempt whose evidence does not resolve is not shown and still sets `misconceived`; the named policy writes Good, Hard, or Again from that. Remove the rule that one unresolved citation leaves the card due.
- Remove the conversational "how did it go" question, or name its reply type and state that the FSRS write has no parameter of that type.
- In "Acceptance before wiring": the bar is two-sided, over-rating and under-rating, plus the share of items that fail grading on a repeated attempt. Delete "Failed items … cannot over-rate." The report includes the length-1 citation rate. State that a frozen model id is not a frozen behavior, and that a wiring decision expires when a fresh evaluation slice misses either bar.
- In `Span`: delete "the credit is the same wherever they occur." When the same consecutive run occurs more than once, the receipt stores the tokens and the multiplicity, and the UI shows those tokens without highlighting one clause. Existence of at least one run is what the schedule's evidence constraint uses. A single highlighted slice is stored only when the run occurs once.
