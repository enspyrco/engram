---
name: extracting-knowledge-graph
description: >
  Extract a knowledge graph (concepts, relationships, quiz items) from wiki
  documents or lecture notes. Use when the user asks to extract knowledge,
  build a concept graph, create quiz cards, ingest documents, or improve
  the extraction pipeline. Produces FSRS-ready quiz items with predicted
  difficulty scores and dependency-aware concept relationships for spaced
  repetition learning. See docs/FSRS_MIGRATION.md for the scheduling migration.
---

# Extracting Knowledge Graph

## Purpose

Transform unstructured wiki/document content into a structured knowledge graph consisting of **concepts**, **relationships**, and **quiz items** with FSRS-ready difficulty predictions for spaced repetition learning. See `references/scheduling-constraints.md` for scheduling details.

## When to Use

- Ingesting documents from Outline wiki or other sources
- Generating or refining extraction prompts for Claude API tool-use
- Reviewing or improving extraction quality
- Debugging why concepts/relationships/quiz items aren't extracting well
- Adding new relationship types or quiz formats

## Extraction Workflow

### Phase 1: Document Preparation

1. Receive document title and full text content
2. Receive list of **existing concept IDs** already in the graph (for reuse, not duplication)
3. Validate content is non-empty before proceeding

### Phase 2: Knowledge Extraction via Claude API

Use Claude with **forced tool calling** (`ToolChoice.tool`) on an `extract_knowledge` tool. The tool schema enforces structured output. See `references/extraction-schema.md` for the full schema.

#### Extraction Rules

**Concepts (quantity driven by document density):**
- Extract all significant concepts. Let document density guide quantity — a brief glossary may yield 2-3, a dense technical article may yield 15-20. Favor precision over volume.
- IDs must be **canonical lowercase kebab-case** (e.g., `docker-compose`, `sm2-algorithm`)
- **REUSE existing concept IDs** when a concept already exists in the graph — this prevents duplicates across documents
- Each concept gets: `id`, `name`, `description` (1-3 sentences), optional `tags`
- Track `sourceDocumentId` to know which document produced each concept

**Relationships:**
- Create relationships between concepts, including **cross-document connections** using existing concept IDs
- Use `"depends on"` label for prerequisites; other labels for non-prerequisite connections
- See `references/relationship-types.md` for the full relationship taxonomy
- Each relationship: `id`, `fromConceptId`, `toConceptId`, `label`, optional `description`

**Quiz Items (1-3 per concept):**
- Clear, concise questions testing understanding of the concept
- Answers should be **1-3 sentences** — not too short to be ambiguous, not too long to be a paragraph
- Each item: `id`, `conceptId`, `question`, `answer`
- Each item includes a **`predictedDifficulty`** score (1-10) — Claude's estimate of how hard this item is to learn. Used as FSRS initial D₀. See `references/scheduling-constraints.md`
- SM-2 defaults are still applied at merge time for legacy compatibility, but FSRS uses the predicted difficulty

### Phase 3: Validation

After extraction, **before merging into the graph**:

1. **Skip orphaned relationships** — if `fromConceptId` or `toConceptId` doesn't match any extracted concept **or existing graph concept**, drop the relationship
2. **Skip orphaned quiz items** — if `conceptId` doesn't match any extracted concept, drop the item
3. Log what was skipped for debugging

### Phase 4: Graph Merge

1. If re-extracting a document, **remove all old concepts/relationships/quiz items** from that document first
2. Add new concepts with `sourceDocumentId` set
3. Add relationships (only if both endpoints exist in the full graph)
4. Add quiz items (only if the concept exists)
5. Update `DocumentMetadata` with collection info and `ingestedAt` timestamp

#### Staggered Ingestion (for UI)

When merging into a live graph with force-directed visualization:
- Reveal concepts in **batches of 3**
- **250ms delay** between batches
- Allows the force-directed layout to settle without O(N^2) rebuilds
- Save only the **final state** to storage (not each batch)

## Quality Guidelines

### Good Concept Examples

| Document Content | Concept ID | Name | Why Good |
|---|---|---|---|
| "Docker Compose orchestrates multi-container apps" | `docker-compose` | Docker Compose | Kebab-case, canonical name |
| "The SM-2 algorithm schedules reviews" | `sm2-algorithm` | SM-2 Algorithm | Reuses existing ID if already in graph |

### Good Quiz Item Examples

| Concept | Question | Answer | Why Good |
|---|---|---|---|
| `docker-compose` | What problem does Docker Compose solve? | Docker Compose orchestrates multi-container Docker applications, allowing you to define and run multiple services with a single configuration file. | Concise, tests understanding not memorization |
| `sm2-algorithm` | How does SM-2 adjust the review interval after a failed response? | SM-2 resets the interval to 1 day and sets repetitions back to 0, while adjusting the ease factor downward based on the quality grade. | Tests mechanism, answer is precise |

### Anti-Patterns to Avoid

- **Overly granular concepts**: Don't create a concept for every paragraph. Favor precision over volume.
- **Trivial quiz items**: "What is X?" with answer "X is X." — test understanding, not definitions
- **Duplicate concepts**: Always check `existingConceptIds` before creating a new ID. If `kubernetes` already exists, reuse it.

## Sub-Concept Splitting

When a quiz card tests multiple distinct ideas, split the parent concept:

1. Create **2-4 sub-concepts**, each covering a distinct aspect
2. Sub-concept IDs **extend the parent** (e.g., `docker-compose` -> `docker-compose-services`, `docker-compose-networking`)
3. Each sub-concept gets **1-2 focused quiz items**
4. Sub-concepts should be independently understandable
5. Set `parentConceptId` on each sub-concept

## Iterating on Extraction Quality

When extraction results are poor:

1. **Check concept density** — too many concepts dilute quality, too few miss important ideas
2. **Check relationship labels** — wrong labels break dependency-aware unlocking
3. **Check quiz item specificity** — vague questions produce vague learning
4. **Check ID reuse** — duplicate concepts fragment the graph
5. **Review the system prompt** — small prompt changes can dramatically affect extraction quality

## Difficulty Prediction Guidelines

When extracting quiz items, Claude should predict difficulty (1-10) based on:

| Factor | Low Difficulty (1-3) | Medium (4-6) | High Difficulty (7-10) |
|---|---|---|---|
| **Prerequisites** | None or 1 | 2-3 concepts needed | 4+ concepts needed |
| **Abstraction** | Concrete, tangible | Mix of concrete/abstract | Purely abstract |
| **Answer type** | Single fact recall | Explanation of mechanism | Synthesis across concepts |
| **Information density** | 1 key point | 2-3 related points | Multiple interacting ideas |
| **Confusion potential** | Unique concept | Some similar concepts exist | Easily confused with others |

### Difficulty Prediction Examples

| Question | Predicted Difficulty | Reasoning |
|---|---|---|
| "What file must every skill contain?" | 2 | Single fact, concrete, no prerequisites |
| "How does progressive disclosure protect the context window?" | 5 | Requires understanding 2 concepts (skills + context window), explains a mechanism |
| "Compare how skills, MCP, and sub-agents manage context window usage" | 8 | Synthesis across 3 concepts, abstract comparison, multiple interacting ideas |

### Auto Sub-Concept Suggestion

If predicted difficulty > 8, flag the quiz item for potential **sub-concept splitting**:
- The question likely tests multiple distinct ideas
- Each idea should become its own concept with difficulty 4-6
- This prevents FSRS from scheduling a card that's inherently too hard to answer atomically

## File References

- `references/extraction-schema.md` — Full JSON schema for the `extract_knowledge` tool
- `references/relationship-types.md` — Relationship type taxonomy and usage guidelines
- `references/scheduling-constraints.md` — FSRS/SM-2 scheduling parameters and how they interact with extraction
