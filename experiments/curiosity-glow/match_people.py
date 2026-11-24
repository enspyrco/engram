#!/usr/bin/env python3
"""Runs on the compute host (it has the sentence-transformers venv). Reads {members:[{id,name,building,knows}]}
on stdin, returns {nodes, edges, missing, known, suppressed} on stdout.

The curvature engine: TWO distance metrics.
  - idea-space distance  = 1 - cosine(embedding(building_i), embedding(building_j))
  - social distance      = geodesic on the "who already knows whom" graph (knows[])

Carnot's metric, faithfully (same as the doc-graph build_graph.py):
  curiosity(i) = avg(sim to top-K most-similar NON-known) - avg(sim to KNOWN)
A person glows when they are pulled toward idea-twins they are NOT yet connected to.
A *fold* is chord-close (high embedding sim) BUT geodesic-far (not already known) — the
connection the room can't see. Pairs that are both close AND already known are SUPPRESSED.
"""
import sys, json
import numpy as np
from sentence_transformers import SentenceTransformer

d = json.load(sys.stdin)
ms = d["members"]
N = len(ms)
if N < 2:
    print(json.dumps({"nodes": [], "edges": [], "missing": [], "known": [], "suppressed": []})); sys.exit(0)

K = 3
id2i = {m["id"]: i for i, m in enumerate(ms)}

# symmetric "already knows" adjacency (the geodesic baseline we subtract)
linked = [set() for _ in range(N)]
for i, m in enumerate(ms):
    for kid in (m.get("knows") or []):
        j = id2i.get(kid)
        if j is not None and j != i:
            linked[i].add(j); linked[j].add(i)

model = SentenceTransformer("all-MiniLM-L6-v2")
emb = model.encode([m["building"] for m in ms], normalize_embeddings=True)
sim = emb @ emb.T                 # cosine, since normalized
np.fill_diagonal(sim, -1.0)

# --- curiosity (Carnot) + per-person directed folds (non-known neighbours) ---
nodes, missing = [], []
for i, m in enumerate(ms):
    order = [int(j) for j in np.argsort(-sim[i]) if sim[i][j] > -1]
    nonknown = [j for j in order if j not in linked[i]][:K]
    known_j  = list(linked[i])
    avg_non = float(np.mean([sim[i][j] for j in nonknown])) if nonknown else 0.0
    avg_lk  = float(np.mean([sim[i][j] for j in known_j])) if known_j else 0.0
    nodes.append({"id": m["id"], "name": m["name"], "building": m["building"],
                  "curiosity": round(avg_non - avg_lk, 4)})
    for j in nonknown:
        if sim[i][j] > 0:
            missing.append({"a": m["id"], "b": ms[j]["id"], "sim": round(float(sim[i][j]), 4)})

# --- deduped folds to actually propose (each person's strongest NON-known match) ---
seen, edges = set(), []
for i in range(N):
    cand = [j for j in (int(x) for x in np.argsort(-sim[i])) if sim[i][j] > 0 and j not in linked[i]]
    if not cand:
        continue
    a, b = sorted((i, cand[0]))
    if (a, b) in seen:
        continue
    seen.add((a, b))
    edges.append({"a": ms[a]["id"], "b": ms[b]["id"], "sim": round(float(sim[a][b]), 4)})
edges.sort(key=lambda e: -e["sim"])

# --- known edges (already connected) — drawn solid, never proposed ---
ks, known = set(), []
for i in range(N):
    for j in linked[i]:
        a, b = sorted((i, j))
        if (a, b) in ks:
            continue
        ks.add((a, b))
        known.append({"a": ms[a]["id"], "b": ms[b]["id"], "sim": round(float(sim[a][b]), 4)})

# --- suppressed = idea-close pairs we did NOT propose because they already know each other ---
suppressed = sorted([k for k in known if k["sim"] > 0], key=lambda e: -e["sim"])

print(json.dumps({"nodes": nodes, "edges": edges, "missing": missing,
                  "known": known, "suppressed": suppressed}))
