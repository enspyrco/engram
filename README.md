# Engram

A Flutter app that reads an [Outline](https://www.getoutline.com/) wiki, uses the Claude API to extract a knowledge graph (concepts, relationships, and quiz items), and teaches it back via spaced repetition (SM-2 + FSRS). A visual knowledge graph "lights up" as you learn.

## Features

- **Knowledge extraction** — Point at an Outline wiki collection, Claude extracts concepts, relationships, and quiz questions automatically
- **Spaced repetition** — SM-2 scheduler with FSRS engine alongside (migrating to FSRS — see `docs/FSRS_MIGRATION.md`), collection-scoped quiz sessions
- **Knowledge graph visualization** — Force-directed graph with mastery coloring (grey > red > amber > green), glow effects on mastered nodes. Incremental layout with pinned nodes: existing concepts stay fixed while new ones animate into position during ingestion
- **Cooperative game** — Guardian system for concept clusters, team goals, glory board leaderboard, repair missions with bonus scoring
- **Social** — Wiki-URL-based friend discovery, challenges (test a friend on your mastered cards), nudges (remind about overdue reviews)
- **Network health** — Composite health scoring with catastrophe tiers (healthy > brownout > cascade > fracture > collapse)

## Architecture

- **Flutter** + **Riverpod** (manual, no codegen) for state management
- **Firebase Auth** (Google + Apple Sign-In) for authentication
- **Cloud Firestore** for storage and sync (migrating to local-first — see `docs/LOCAL_FIRST.md`)
- **Claude API** (`anthropic_sdk_dart`) for concept extraction
- **Custom `ForceDirectedGraphWidget`** with `CustomPainter` + Fruchterman-Reingold layout, pinned incremental updates

See `CLAUDE.md` for detailed architecture documentation.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

## Design Documents

- `docs/SYNAPTIC_WEB_GAME_DESIGN.md` — Creative vision for the cooperative network game
- `docs/GRAPH_STATE_MANAGEMENT.md` — Analysis of graph-based state management options
- `docs/LOCAL_FIRST.md` — Local-first architecture plan
- `docs/CRDT_SYNC_ARCHITECTURE.md` — CRDT sync design for multi-device consistency
- `docs/FSRS_MIGRATION.md` — Migration from SM-2 to FSRS spaced repetition
