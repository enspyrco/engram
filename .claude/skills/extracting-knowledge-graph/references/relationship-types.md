# Relationship Type Taxonomy

## Core Relationship Types

### `depends on` (Prerequisite)

The most important relationship type. Drives **concept unlocking** — a concept cannot be unlocked for quiz sessions until all its prerequisites are mastered.

**Use when:** Concept A cannot be understood without first understanding Concept B.

**Direction:** `A --depends on--> B` means "A requires B"

**Examples:**
- `docker-compose --depends on--> docker-containers`
- `sm2-ease-factor --depends on--> sm2-algorithm`
- `react-hooks --depends on--> react-components`

**Impact on learning:** The `GraphAnalyzer` performs topological sort on "depends on" edges. Concepts with no unsatisfied prerequisites are "unlocked" and eligible for quiz sessions. Getting this wrong breaks the learning order.

### `is a type of` (Taxonomy)

Hierarchical classification. Does NOT create a prerequisite — both can be learned independently.

**Use when:** Concept A is a specific instance or subtype of Concept B.

**Examples:**
- `binary-search --is a type of--> search-algorithm`
- `postgresql --is a type of--> relational-database`

### `enables` (Capability)

Concept A makes Concept B possible or practical. Weaker than "depends on" — B can be understood without A, but A makes B achievable.

**Use when:** Learning A opens the door to doing B, but B's concept can be understood independently.

**Examples:**
- `docker-compose --enables--> microservice-deployment`
- `ci-cd-pipeline --enables--> continuous-deployment`

### `related to` (Association)

General semantic connection. Use sparingly — it's the catch-all when no other type fits.

**Use when:** Concepts are connected but none of the above types apply.

**Examples:**
- `kubernetes --related to--> docker-compose` (both orchestrate containers, but neither depends on the other)

## Guidelines

### Choosing the Right Type

```
Can A be understood without B?
  NO  --> "depends on"
  YES --> Is A a subtype of B?
    YES --> "is a type of"
    NO  --> Does A make B practically achievable?
      YES --> "enables"
      NO  --> "related to"
```

### Common Mistakes

| Mistake | Why It's Wrong | Correct |
|---|---|---|
| Everything "related to" | Loses prerequisite information, breaks unlock order | Use "depends on" for real prerequisites |
| Circular "depends on" | Creates cycles, breaks topological sort | Check that A truly can't exist without B |
| Cross-document relationships | May reference concepts not yet extracted | Only relate concepts from the SAME document |
| Reversed direction | `A depends on B` means A needs B, not B needs A | Think "A requires knowledge of B" |

### Future: Typed Relationships (Issue #38)

The current four types are intentionally simple. Issue #38 proposes expanding to include:
- `analogy` — cross-discipline semantic connections
- `contrast` — explicit differences between similar concepts
- `composition` — part-of relationships

These would enhance the mind map visualization and enable cross-discipline discovery.
