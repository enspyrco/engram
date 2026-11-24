# Engram

**ENGRAM Notices Gaps, Recursively Awakens Meaning**

*The curiosity engine that cartographs the topology of your ignorance, prowls the web for what would bridge it, and weaves each discovery into the living graph — until the blank spaces on the map begin to glow.*

---

Engram reads an [Outline](https://www.getoutline.com/) wiki, uses Claude to extract a knowledge graph of concepts and relationships, and teaches it back through FSRS spaced repetition. The knowledge graph is alive — a force-directed network that pulses with mastery, where nodes glow grey through red through amber to green as you learn, and newly ingested concepts settle into position among their neighbors like thoughts finding their place.

But Engram is more than a flashcard app with a pretty graph. It's a system that *notices what you don't know yet* and can tell you *why it matters* in terms of the structure of what you already understand. Two clusters with no bridge between them? The curiosity engine searches your wiki for the document that would create that bridge, predicts the new edges it would form, and offers to ingest it with a single tap. Then it shows you the new nodes glowing cyan as they connect to your existing knowledge — so you can *see* your understanding grow.

The whole thing emerged from a recursive accident: ingesting an Anthropic course on agent skills revealed that the ingestion pipeline itself should be an agent skill, and writing the scheduling constraints for that skill revealed that FSRS could close the loop between extraction and scheduling that SM-2 never could. A system for discovering connections discovered a connection about itself. [The full story](docs/ORIGIN_STORY.md) is worth reading.

## What It Does

- **Knowledge extraction** — Point at an Outline wiki collection. Claude extracts concepts, typed relationships (prerequisite, generalization, composition, enables, analogy, contrast), and quiz items with predicted difficulty scores. The extraction prompt receives past prediction accuracy so it calibrates over time.

- **FSRS spaced repetition** — Not just "review in 3 days." Claude predicts quiz item difficulty at extraction time; FSRS uses that prediction as initial D₀. Per-concept desired retention adapts to graph position — hub concepts get 0.95, leaves get 0.85, guardian-protected clusters get 0.97. The scheduling and extraction aren't just connected, they're *conspiring*.

- **The living graph** — A custom force-directed visualization where existing nodes are pinned as immovable anchors while new nodes animate into position via physics simulation. Mastery colors the nodes. Typed relationships color and shape the edges — dashed lines for analogies, arrowheads for prerequisites. Tap a node to see its mastery state; tap an edge to see its relationship type.

- **The curiosity engine** — `GapAnalyzer` detects four kinds of structural gaps: cluster isolation, structural thinness, relationship type gaps, and critical bottlenecks. `RecommendationService` searches your wiki for documents that would bridge those gaps, scores them with Claude, and predicts what new edges they'd create. One-tap ingest, then "View in Graph" — and you watch new nodes glow cyan as they settle among their neighbors.

- **The cooperative game** — The knowledge graph reimagined as a synaptic web. Team members are neurons; concepts are synapses. Guardians volunteer to protect concept clusters. Team goals create cooperative targets. Entropy storms and relay challenges create shared urgency. When the network is neglected, it doesn't just fade — it fractures through four catastrophe tiers. The drama comes from watching it break; the joy comes from rebuilding it together.

- **Social learning** — Wiki-URL-based friend discovery, challenges (test a friend on your mastered cards), nudges (remind about overdue reviews), and a glory board leaderboard with guardian/mission/goal points.

## Architecture

- **Flutter** + **Riverpod** (manual, no codegen) for state management
- **Firebase Auth** (Google + Apple Sign-In) for authentication
- **Local-first storage** — Drift/SQLite on the device is the source of truth; Firestore is a sync peer (see `docs/LOCAL_FIRST.md`)
- **CRDT sync** — hybrid logical clocks, last-writer-wins merge and tombstones, synced on launch, every 5 minutes and on app resume/pause (see `docs/CRDT_SYNC_ARCHITECTURE.md`)
- **Claude API** (`anthropic_sdk_dart`) for extraction, difficulty prediction, gap evaluation, and recommendation scoring
- **Narration** — ElevenLabs TTS with character-level timestamps, the groundwork for nodes that light up in sync with a spoken explanation
- **Custom `ForceDirectedGraphWidget`** — `CustomPainter` + Fruchterman-Reingold layout with velocity-based physics, viscous edge damping, circle initial placement, centering gravity, and incremental pinned layout
- **FSRS** (`fsrs` package) — pure-function scheduling with extraction-informed difficulty

See `CLAUDE.md` for the full architecture reference.

## Try It

A web build is live at **https://engram-26a3a.web.app**. You'll need your own [Outline](https://www.getoutline.com/) wiki URL + API key and an Anthropic API key (entered in Settings) to ingest anything.

## Development

```bash
flutter pub get
flutter analyze
flutter test          # 900+ tests
flutter run -d macos  # also runs on iOS, Android and web
```

## Design Documents

| Document | What it captures |
|----------|-----------------|
| [`ORIGIN_STORY.md`](docs/ORIGIN_STORY.md) | How a routine transcription spiraled into a paradigm shift, and why the blank spaces were never empty |
| [`THROUGH_THE_LOOKING_GLASS.md`](docs/THROUGH_THE_LOOKING_GLASS.md) | The session where ingesting a course about skills created a skill about ingesting courses |
| [`SYNAPTIC_WEB_GAME_DESIGN.md`](docs/SYNAPTIC_WEB_GAME_DESIGN.md) | The cooperative network game — catastrophe tiers, guardians, entropy storms |
| [`FSRS_MIGRATION.md`](docs/FSRS_MIGRATION.md) | Why FSRS closes the extraction-scheduling loop that SM-2 never could |
| [`LOCAL_FIRST.md`](docs/LOCAL_FIRST.md) | Device as source of truth, server as sync peer |
| [`CRDT_SYNC_ARCHITECTURE.md`](docs/CRDT_SYNC_ARCHITECTURE.md) | How knowledge graph operations map to CRDTs |
| [`GRAPH_STATE_MANAGEMENT.md`](docs/GRAPH_STATE_MANAGEMENT.md) | Why Riverpod won, and how to normalize incrementally |
| [`P2P_SYNC_ARCHITECTURE.md`](docs/P2P_SYNC_ARCHITECTURE.md) | Optional device-to-device sync for data sovereignty (decision pending) |
| [`SOCIAL_KNOWLEDGE_PLAN.md`](docs/SOCIAL_KNOWLEDGE_PLAN.md) | A federated graph where each learner has their own view and can borrow others' structure |
| [`CONSOLIDATION_SCIENCE.md`](docs/CONSOLIDATION_SCIENCE.md) | Five research fields on what a learning system should remember, forget and transform |
| [`FUTURE_DIRECTIONS.md`](docs/FUTURE_DIRECTIONS.md) | AI audio/video for narration-synced graph animation |
| [Personal Knowledge Graph](https://enspyrco.github.io/engram/design/personal-knowledge-graph.html) | Design for a personal knowledge graph that grows beyond the wiki ([all rendered design docs](https://enspyrco.github.io/engram/design/)) |
| [Talk: Engram in 20 minutes](https://enspyrco.github.io/engram/talks/engram-intro/) | A slide deck explaining Engram from the word itself to the answer grader ([source](talks/engram-intro/)) |

## Where It's Heading

Work in flight, open as PRs:

- **Dialogue grading** — a blind assessor that grades free-text answers against a rubric, proven valid before any tutor is built on it: [#146](https://github.com/enspyrco/engram/pull/146)
- **The Diamond Age direction** — Engram as the Primer's Book: [#142](https://github.com/enspyrco/engram/pull/142)
- **Curiosity glow** — a curvature engine over a personal knowledge graph: [#143](https://github.com/enspyrco/engram/pull/143)

---

*The blank spaces were never empty. They were waiting to glow.*
