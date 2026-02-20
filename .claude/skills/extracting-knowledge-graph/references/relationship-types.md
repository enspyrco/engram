# Relationship Type Taxonomy

## Core Relationship Types

All relationships have an explicit `type` field from the `RelationshipType` enum, plus a natural-language `label` for display. Legacy data without a `type` field falls back to inference from the label via `RelationshipType.inferFromLabel()`.

### `prerequisite`

The most important relationship type. Drives **concept unlocking** — a concept cannot be unlocked for quiz sessions until all its prerequisites are mastered.

**Use when:** Concept A cannot be understood without first understanding Concept B.

**Direction:** `A --depends on--> B` means "A requires B"

**Examples:**
- `docker-compose --depends on--> docker-containers`
- `sm2-ease-factor --depends on--> sm2-algorithm`
- `react-hooks --depends on--> react-components`

**Impact on learning:** The `GraphAnalyzer` performs topological sort on prerequisite edges. Concepts with no unsatisfied prerequisites are "unlocked" and eligible for quiz sessions. Getting this wrong breaks the learning order.

**Visual:** Thick white line with arrowhead.

### `generalization`

Hierarchical classification. Does NOT create a prerequisite — both can be learned independently.

**Use when:** Concept A is a specific instance or subtype of Concept B.

**Examples:**
- `binary-search --is a type of--> search-algorithm`
- `postgresql --is a type of--> relational-database`

**Visual:** Medium cyan line.

### `composition`

Part-of relationship. Concept A is a component of Concept B.

**Use when:** Concept A is structurally part of Concept B.

**Examples:**
- `docker-volume --part of--> docker-compose`
- `tcp-handshake --part of--> tcp-protocol`

**Visual:** Medium teal line.

### `enables`

Concept A makes Concept B possible or practical. Weaker than prerequisite — B can be understood without A, but A makes B achievable.

**Use when:** Learning A opens the door to doing B, but B's concept can be understood independently.

**Examples:**
- `docker-compose --enables--> microservice-deployment`
- `ci-cd-pipeline --enables--> continuous-deployment`

**Visual:** Medium purple line with arrowhead.

### `analogy`

Cross-discipline semantic similarity. Connects concepts from different domains that share structural or functional similarities.

**Use when:** Concepts from different fields exhibit similar patterns or mechanisms.

**Examples:**
- `thermodynamic-entropy --analogous to--> information-entropy`
- `natural-selection --analogous to--> gradient-descent`

**Visual:** Thin dashed orange line.

### `contrast`

Explicit difference between similar concepts. Helps learners distinguish easily confused ideas.

**Use when:** Two concepts are frequently confused or have important differences worth highlighting.

**Examples:**
- `concurrency --contrasts with--> parallelism`
- `authentication --contrasts with--> authorization`

**Visual:** Thin dashed pink line.

### `relatedTo`

General semantic connection. Use sparingly — it's the catch-all when no other type fits.

**Use when:** Concepts are connected but none of the above types apply.

**Examples:**
- `kubernetes --related to--> docker-compose` (both orchestrate containers, but neither depends on the other)

**Visual:** Thin grey line.

## Guidelines

### Choosing the Right Type

```
Can A be understood without B?
  NO  --> prerequisite
  YES --> Is A a subtype of B?
    YES --> generalization
    NO  --> Is A a component of B?
      YES --> composition
      NO  --> Does A make B practically achievable?
        YES --> enables
        NO  --> Are A and B from different domains with similar structure?
          YES --> analogy
          NO  --> Are A and B easily confused / importantly different?
            YES --> contrast
            NO  --> relatedTo
```

### Common Mistakes

| Mistake | Why It's Wrong | Correct |
|---|---|---|
| Everything `relatedTo` | Loses prerequisite information, breaks unlock order | Use `prerequisite` for real prerequisites |
| Circular prerequisites | Creates cycles, breaks topological sort | Check that A truly can't exist without B |
| Reversed direction | `A depends on B` means A needs B, not B needs A | Think "A requires knowledge of B" |
| `enables` when `prerequisite` | If A truly can't be understood without B, that's a prerequisite | Reserve `enables` for "makes practical" |
