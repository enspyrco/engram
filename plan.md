# Engram

> *"I know Kung Fu."* — Neo
>
> LLM-powered knowledge extraction and spaced-repetition learning from your Outline wiki.
> Engram reads your team's wiki, understands how concepts connect, builds a knowledge graph, and teaches it back to you — foundational concepts first, then deeper layers as mastery builds.

## Vision

Traditional flashcards treat every card as independent. Engram treats knowledge as a **graph** — concepts are nodes, relationships are edges. Learning follows the topology: you can't understand "Kubernetes Services" until you understand "Pods", and you can't understand "Pods" until you understand "Containers."

An LLM reads your Outline wiki and extracts this structure automatically. Then a spaced-repetition engine quizzes you along the graph, unlocking deeper nodes as you demonstrate mastery of their prerequisites.

## Architecture

```
┌──────────────┐      ┌──────────────┐      ┌──────────────────┐
│  Outline API │─────▶│  LLM Engine  │─────▶│  Knowledge Graph  │
│  (wiki docs) │      │  (Claude API)│      │  (nodes + edges)  │
└──────────────┘      └──────────────┘      └────────┬─────────┘
                                                     │
                                                     ▼
                                            ┌──────────────────┐
                                            │  Quiz Engine     │
                                            │  (SM-2 per node) │
                                            └────────┬─────────┘
                                                     │
                                                     ▼
                                            ┌──────────────────┐
                                            │  UI              │
                                            │  (graph viz +    │
                                            │   quiz interface)│
                                            └──────────────────┘
```

## Core Components

### 1. Outline Ingestion Service
- Connect to Outline API to fetch all documents from target collections
- Track document revisions so re-ingestion only reprocesses changed docs
- Store raw document content locally or in Firestore for processing
- Periodic sync (webhook from Outline or cron-based polling)

### 2. LLM Knowledge Extraction
- For each document, call Claude API with structured output to extract:
  - **Concepts**: Key terms, tools, patterns, ideas (these become graph nodes)
  - **Relationships**: How concepts connect to each other
    - `depends_on` — X requires understanding Y first
    - `is_a` — X is a type/instance of Y
    - `uses` — X uses/leverages Y
    - `contrasts_with` — X is an alternative to Y
  - **Difficulty level**: foundational / intermediate / advanced
  - **Quiz material**: For each concept, generate:
    - A concise definition (for "what is X?" cards)
    - Relationship questions ("how does X relate to Y?")
    - Application questions ("when would you use X over Y?")
- De-duplicate concepts across documents (LLM identifies when two docs reference the same concept)
- Re-run extraction when documents change (delta processing)

#### Example LLM output for a wiki page about Docker:
```json
{
  "concepts": [
    {
      "id": "docker-container",
      "name": "Docker Container",
      "definition": "A lightweight, standalone executable package that includes everything needed to run a piece of software.",
      "difficulty": "foundational",
      "source_doc": "doc_abc123"
    },
    {
      "id": "docker-image",
      "name": "Docker Image",
      "definition": "A read-only template used to create containers. Built from a Dockerfile.",
      "difficulty": "foundational",
      "source_doc": "doc_abc123"
    },
    {
      "id": "docker-compose",
      "name": "Docker Compose",
      "definition": "A tool for defining and running multi-container Docker applications using a YAML file.",
      "difficulty": "intermediate",
      "source_doc": "doc_abc123"
    }
  ],
  "relationships": [
    { "from": "docker-container", "to": "docker-image", "type": "depends_on", "description": "Containers are instantiated from images" },
    { "from": "docker-compose", "to": "docker-container", "type": "depends_on", "description": "Compose orchestrates multiple containers" }
  ],
  "quiz_items": [
    { "concept": "docker-container", "type": "definition", "question": "What is a Docker container?", "answer": "A lightweight, standalone executable package..." },
    { "concept": "docker-compose", "type": "relationship", "question": "What is the relationship between Docker Compose and containers?", "answer": "Compose defines and orchestrates multiple containers using a YAML config" },
    { "concept": "docker-compose", "type": "application", "question": "When would you use Docker Compose instead of running containers individually?", "answer": "When you have multiple interdependent services that need to be started together with shared networking" }
  ]
}
```

### 3. Knowledge Graph Store
- Store the graph in a format that supports:
  - Node lookup by ID
  - Edge traversal (what depends on X? what does X depend on?)
  - Topological sorting (what are the foundational concepts with no prerequisites?)
  - Subgraph extraction (give me the learning path from A to B)
- Options:
  - **Simple**: JSON file or SQLite with adjacency list (good enough to start)
  - **Later**: Firestore if you want cross-device sync

### 4. Spaced-Repetition Engine (SM-2)
- Implement SM-2 algorithm per quiz item:
  - Each item has: `ease_factor`, `interval`, `repetitions`, `next_review_date`
  - After each review, quality score (0-5) updates the schedule
- **Graph-aware scheduling**:
  - Never quiz on a concept whose prerequisites haven't reached a minimum mastery threshold
  - When a prerequisite's mastery drops (failed review), lock dependent concepts until it recovers
  - Prioritize foundational concepts in early sessions
  - Gradually unlock deeper layers as the graph "lights up"

### 5. UI — Two Modes

#### Mind Map View
- Visual graph of all concepts, colored by mastery:
  - **Grey**: Locked (prerequisites not yet mastered)
  - **Red**: Due for review / low mastery
  - **Amber**: Learned but not yet solid
  - **Green**: Well-mastered
- Tap a node to see its definition, source wiki page, and connections
- Zoom into sub-graphs (e.g., just the "Docker" cluster)

#### Quiz Mode
- Pull the next due items from the SM-2 scheduler (filtered by graph readiness)
- Show question → user thinks → reveal answer → self-rate (1-5)
- Session summary: concepts reviewed, mastery changes, newly unlocked nodes
- "What's next" preview: which concepts are close to unlocking

## Tech Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Ingestion | Dart CLI or server | Fits existing 10xdeca Dart ecosystem |
| LLM extraction | Claude API (tool use / structured output) | Best at nuanced concept extraction |
| Graph store | SQLite (local) or Firestore (sync) | Start simple, scale later |
| Quiz engine | Dart library | SM-2 is ~30 lines, keep it in-repo |
| UI | Flutter | Cross-platform, existing team expertise |
| Graph visualization | `flutter_force_directed_graph` or custom Canvas paint | Interactive mind map |

## Implementation Phases

### Phase 1 — Proof of Concept (CLI)
1. Write Outline API client — fetch docs from a single collection
2. Write Claude API prompt — extract concepts + relationships from one doc
3. Iterate on prompt until extraction quality is good
4. Store output as JSON
5. Build a minimal CLI quiz loop (no graph scheduling yet, just random SM-2 cards)
6. **Milestone**: You can quiz yourself on concepts from one wiki collection

### Phase 2 — Graph Intelligence
1. Process multiple documents, de-duplicate concepts across them
2. Build the dependency graph from extracted relationships
3. Implement graph-aware scheduling (topological learning order)
4. Add prerequisite locking/unlocking logic
5. **Milestone**: Quiz order respects concept dependencies

### Phase 3 — Flutter App
1. Scaffold Flutter app
2. Build quiz UI (question → reveal → rate flow)
3. Build mind map visualization (force-directed graph)
4. Color nodes by mastery level
5. Session summaries and progress tracking
6. **Milestone**: Visual mind map that "lights up" as you learn

### Phase 4 — Sync & Polish
1. Move graph store to Firestore for cross-device sync
2. Webhook or periodic re-ingestion when Outline docs change
3. Delta processing (only re-extract changed docs)
4. Notification: "You have 12 concepts due for review"
5. **Milestone**: Living system that grows with your wiki

## Open Questions
- Should the graph be per-collection or wiki-wide?
- Should quiz items be purely auto-generated or allow manual additions?
- Is there value in multiplayer/team mode (see what teammates have mastered)?
- Should concept mastery data feed back into Outline (e.g., tag pages as "well-understood" by the team)?
