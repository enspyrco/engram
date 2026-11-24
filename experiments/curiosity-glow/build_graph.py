#!/usr/bin/env python3
"""Curiosity-gap glow — build the graph.

Carnot's metric, faithfully:
  curiosity(i) = avg(similarity to top-K most-similar NON-linked docs)
               - avg(similarity to LINKED docs)
High curiosity = "this note strongly implies neighbours it does not yet have."

"Linked" = same-collection siblings  ∪  explicit /doc/ links  ∪  parent/child.
So a doc glows when it is semantically pulled toward knowledge it is *siloed away from*
(a different collection or the other wiki) — the cross-silo gap made visible.
"""
import json, re, os, sys
import numpy as np
from sentence_transformers import SentenceTransformer

CORPUS = os.environ.get("CORPUS", os.path.expanduser("~/curiosity-glow-spike/corpus.json"))
OUT    = os.environ.get("OUT", os.path.expanduser("~/curiosity-glow-spike/graph.json"))
K_NONLINKED = 10
TOP_MISSING = 3
GLOW_THRESHOLD = 0.0  # surface missing-edges for nodes above this normalized curiosity

docs = json.load(open(CORPUS))
n = len(docs)
print(f"{n} docs")

# --- urlId -> index, for resolving explicit /doc/ links (within a site) ---
url_to_idx = {}
for i, d in enumerate(docs):
    url_to_idx[(d["site"], d["urlId"])] = i
LINK_RE = re.compile(r"/doc/[^)\s]*?-([A-Za-z0-9]{8,16})\b")

# --- embed (title carries a lot of signal; cap body) ---
model = SentenceTransformer("all-MiniLM-L6-v2")
texts = [f"{d['title']}\n\n{d['text'][:2000]}" for d in docs]
emb = model.encode(texts, batch_size=32, show_progress_bar=True, normalize_embeddings=True)
sim = emb @ emb.T          # cosine, since normalized
np.fill_diagonal(sim, -1.0)

# --- existing-edge / linked sets ---
explicit = [set() for _ in range(n)]   # only explicit links + parent/child -> drawn as real edges
linked   = [set() for _ in range(n)]   # full "linked" set for the metric (adds same-collection)

by_collection = {}
for i, d in enumerate(docs):
    by_collection.setdefault((d["site"], d["collectionId"]), []).append(i)

# explicit doc-links
for i, d in enumerate(docs):
    for m in LINK_RE.finditer(d["text"]):
        j = url_to_idx.get((d["site"], m.group(1)))
        if j is not None and j != i:
            explicit[i].add(j); explicit[j].add(i)
# parent/child
url_by_parent = {}
for i, d in enumerate(docs):
    pid = d.get("parentDocumentId")
    if pid:
        url_by_parent.setdefault(pid, []).append(i)
# (parentDocumentId is a doc *id*, not urlId; we only have urlId here, so parent/child
#  is best-effort — most hierarchy in these wikis is collection-flat anyway.)

# linked = explicit ∪ same-collection siblings
for i, d in enumerate(docs):
    linked[i] |= explicit[i]
    for j in by_collection[(d["site"], d["collectionId"])]:
        if j != i:
            linked[i].add(j)

# --- curiosity ---
raw = np.zeros(n)
missing = []  # top-3 cross-group candidates per node
for i in range(n):
    order = np.argsort(-sim[i])
    nonlinked = [j for j in order if j not in linked[i] and sim[i][j] > -1][:K_NONLINKED]
    lk = list(linked[i])
    avg_non = float(np.mean(sim[i][nonlinked])) if nonlinked else 0.0
    avg_lk  = float(np.mean(sim[i][lk])) if lk else 0.0
    raw[i] = avg_non - avg_lk
    for j in nonlinked[:TOP_MISSING]:
        missing.append({"source": i, "target": int(j), "sim": round(float(sim[i][j]), 3)})

# normalize curiosity 0..1 for glow intensity
lo, hi = float(raw.min()), float(raw.max())
norm = (raw - lo) / (hi - lo + 1e-9)

# collection -> stable small int for colouring
coll_ids = sorted({(d["site"], d["collectionId"]) for d in docs})
coll_idx = {c: k for k, c in enumerate(coll_ids)}

nodes = [{
    "id": i, "key": d["key"], "title": d["title"], "site": d["site"],
    "collection": coll_idx[(d["site"], d["collectionId"])],
    "curiosity": round(float(norm[i]), 3), "raw": round(float(raw[i]), 3),
    "linked": len(explicit[i]),
} for i, d in enumerate(docs)]

links = [{"source": i, "target": int(j)} for i in range(n) for j in explicit[i] if i < j]

json.dump({"nodes": nodes, "links": links, "missing": missing,
           "n_collections": len(coll_ids)}, open(OUT, "w"))

top = sorted(range(n), key=lambda i: -raw[i])[:8]
print(f"\nwrote {OUT}: {n} nodes, {len(links)} explicit edges, {len(missing)} gap-edges")
print("\n=== HOTTEST GAPS (highest curiosity — most pulled toward un-linked knowledge) ===")
for i in top:
    tgt = max((m for m in missing if m["source"] == i), key=lambda m: m["sim"], default=None)
    t = docs[tgt["target"]]["title"] if tgt else "?"
    print(f"  {raw[i]:+.3f} [{docs[i]['site']:12}] {docs[i]['title'][:40]:40} ~~wants~~> {t[:35]}")
