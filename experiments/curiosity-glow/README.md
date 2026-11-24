# curiosity-glow — the curvature engine turned inward

Engram's thesis applied to **one mind's knowledge**: take a personal Outline
corpus (here, ~213 docs across two wikis), embed it as a single graph, and find
the **missing edges** — documents semantically pulled toward knowledge they're
structurally siloed away from. A doc *glows gold* when its nearest neighbours
live across a collection/wiki wall it never links to.

Full design + adversarial-review record: [`personal-knowledge-graph.html`](./personal-knowledge-graph.html).

## Privacy — read before running

The corpus and its derived graph carry **real document titles and body text**.
They are **gitignored and never committed** (`corpus.json`, `graph.json`,
`corpus/`). They live only on the compute host, owner-readable. The code reads
them through environment variables, so the data path is never hardcoded into a
commit:

```bash
export CORPUS=/path/to/corpus.json   # private, gitignored
export OUT=/path/to/graph.json       # private, gitignored
python build_graph.py
```

Any **screenshot** of the rendered viewer also contains private titles — treat
those as private-by-default too.

## Files

| File | What |
|------|------|
| `build_graph.py` | embed corpus → curiosity metric + surprise re-rank → `graph.json` |
| `match_people.py` | the people-cohort variant of the same engine |
| `personal-knowledge-graph.html` | design doc + 3-family adversarial review |

> Status: experimental spike. The design doc's Risks section is the honest
> account of what's validated vs assumed.
