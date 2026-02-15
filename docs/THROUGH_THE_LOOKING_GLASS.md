# Through the Looking Glass

*How a routine transcription task spiraled into a fundamental architectural insight, and what that says about building tools that learn.*

**Date:** February 15, 2026
**Session duration:** ~2 hours
**Lines of code changed:** 0
**Lines of documentation written:** 759
**Paradigm shifts:** 1

---

## Chapter 1: The Transcription

It started simply. Nick had 11 video transcripts from an Anthropic course called "Agent Skills" and wanted them saved as pages in his Outline wiki. Create a collection, paste transcripts, extract titles, save pages. Routine work.

The first hiccup: the Outline wiki had moved from `wiki.xdeca.com` to `kb.xdeca.com`, and the API key in `.env` was stale. A quick fix. The `OutlineClient` in the codebase was read-only — no `createCollection` or `createDocument` methods — so we went direct to the API with curl.

Eleven pages went up. The course covered skills as an open standard, progressive disclosure, composability, the relationship between skills and MCP and sub-agents, how to use skills across Claude AI, the Claude API, Claude Code, and the Agent SDK.

Nothing unusual yet.

## Chapter 2: The Mirror

While summarizing the course content, a pattern emerged. The videos described skills as "folders of instructions that extend an agent's capabilities with specialized knowledge." They described progressive disclosure — only loading what's needed into the context window. They described composability — combining custom skills with built-in ones.

And then the reflection: **Engram's extraction pipeline is exactly the kind of workflow that should be a skill.**

The `ExtractionService` hard-codes a system prompt, a tool schema, validation rules, and merge logic in Dart. It works, but it's:
- Not portable (locked in Dart code)
- Not auditable (prompt changes require code changes)
- Not composable (can't combine with other skills)
- Not progressively disclosed (everything loads always)

The course we'd just ingested contained the blueprint for making the ingestion itself better.

## Chapter 3: The Skill

So we built it. `.claude/skills/extracting-knowledge-graph/` with:

- **SKILL.md** — The full extraction workflow: document preparation, Claude API tool-use with forced calling, validation (skip orphaned relationships and quiz items), graph merge with staggered ingestion for the force-directed visualization
- **references/extraction-schema.md** — The exact JSON schemas for `extract_knowledge` and `suggest_sub_concepts` tools
- **references/relationship-types.md** — A taxonomy of relationship types (`depends on`, `is a type of`, `enables`, `related to`) with a decision flowchart and common mistakes
- **references/sm2-constraints.md** — How SM-2 scheduling interacts with extraction quality

Each reference file only loads when needed. Progressive disclosure — exactly what the course taught.

The skill encoded what was previously tribal knowledge scattered across four Dart files into one coherent, discoverable document. A skill about extracting knowledge, built by extracting knowledge from a course about skills.

Recursive enough yet?

## Chapter 4: The Wall

While writing the scheduling constraints reference, a seemingly innocuous sentence appeared:

> "SM-2 scheduling state is applied AFTER extraction, not during it. Claude has no knowledge of SM-2 when extracting — it focuses purely on content quality."

This was stated as a fact. A design constraint. The extraction service produces `(question, answer)`. The scheduler wraps it in `(question, answer, easeFactor=2.5, interval=0, repetitions=0)`. Claude's understanding of the content's difficulty is **discarded**.

And then Nick asked: **"What if we used FSRS instead?"**

## Chapter 5: Through the Wall

FSRS (Free Spaced Repetition Scheduler) has a parameter called **Difficulty (D)** — and it's a property of the *card*, not the learner. In standard FSRS, initial difficulty comes from the first review rating. But Claude already has the information to predict it:

- How many prerequisites the answer depends on
- Whether the concept is abstract or concrete
- Whether the answer requires synthesis or recall
- How information-dense the answer is

With SM-2, every card starts at `easeFactor: 2.5`. There is nothing Claude can contribute. The loop is forced open.

With FSRS, Claude extracts `(question, answer, predicted_difficulty)`. The scheduler uses that prediction. **The loop is closed.**

This isn't a minor optimization. It means:
- The extraction service and scheduler are no longer decoupled by necessity
- Claude's understanding of content difficulty is preserved and used
- First review intervals already account for complexity (no more surprises)
- Mean reversion prevents SM-2's infamous "ease hell"
- Per-concept `desired_retention` can be set based on graph position (hubs get 0.95, leaves get 0.85, guardian-protected concepts get 0.97)
- The crude `1.5x interval` hack for repair missions becomes a principled retention target

And a pure Dart `fsrs` package exists on pub.dev. 160/160 pub points. MIT license. Drop-in territory.

## Chapter 6: The Ouroboros

Let's trace the full chain:

1. **Engram** is a tool that reads wikis and extracts knowledge graphs
2. We used it (well, its Outline wiki) to **ingest a course** about agent skills
3. The course taught us to **build a skill** that encodes Engram's extraction workflow
4. Writing the skill revealed that **SM-2 forces a wall** between extraction and scheduling
5. FSRS **dissolves that wall** — Claude predicts difficulty at extraction time
6. The skill **updated itself** to include difficulty prediction guidelines
7. The scheduling constraints reference was **renamed and rewritten** from SM-2 to FSRS
8. An ADR was written documenting the **4-phase migration plan**
9. The whole thing was **shipped via PR #52**, reviewed by two AI reviewers in a cage match
10. Both reviewers approved. The cage match caught a real nit (sub-concept schema missing `predictedDifficulty`)

The tool that learns from wikis learned how to learn better, by learning from a course about learning.

The snake ate its own tail. And it tasted good.

## Chapter 7: What Actually Shipped

**PR #52** (`5b8261e`): 6 files, 759 lines, zero Dart code.

- `.claude/skills/extracting-knowledge-graph/` — The extraction skill with FSRS difficulty prediction
- `docs/FSRS_MIGRATION.md` — Architecture decision record with 4-phase migration plan
- `CLAUDE.md` — Updated roadmap, new ADR reference, completed items

Plus 11 pages in Outline wiki and a fundamental rethinking of how extraction and scheduling should relate.

## Chapter 8: What's Next

**FSRS Phase 1** is now top of the roadmap:
1. Add `fsrs` package to pubspec.yaml
2. Add nullable `difficulty` field to `QuizItem`
3. Update extraction tool schema with `predictedDifficulty`
4. Update extraction system prompt with difficulty prediction guidelines
5. Write FSRS engine as pure function
6. Tests

The skill we built will guide the implementation. The ADR documents the reasoning. The course that started it all is in the wiki, ready to be ingested by Engram itself.

## The Lesson

Sometimes the most productive sessions produce zero lines of application code. The 759 lines of documentation in this PR capture architectural decisions, extraction procedures, relationship taxonomies, scheduling constraints, and a migration plan that would otherwise live only in a chat transcript or someone's head.

Documentation is not the absence of work. It's the crystallization of understanding. And sometimes, if you're lucky, the act of writing it down reveals something you didn't know you didn't know.

> "Engram is a tool that learns from wikis. We used it to ingest a course about skills. That course taught us to build a skill that makes Engram's extraction better. And the skill revealed that the scheduling algorithm should change — which in turn changes the skill itself."
>
> "The tool is learning how to learn, and we're learning alongside it."

---

*Written at the end of a session that started with "can you please create a new collection in our outline" and ended with a cage match between MaxwellMergeSlam and KelvinBitBrawler over whether FSRS difficulty prediction was valid. Both approved. The ice man said "Execute Phase 1. Dismissed."*

*So we shall.*
