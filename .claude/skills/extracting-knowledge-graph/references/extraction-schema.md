# Extraction Tool Schema

## Tool: `extract_knowledge`

This is the Claude API tool definition used for structured extraction. Claude is forced to use this tool via `ToolChoice.tool`.

### Input Schema

```json
{
  "type": "object",
  "required": ["concepts", "relationships", "quizItems"],
  "properties": {
    "concepts": {
      "type": "array",
      "description": "Key concepts found in the document (3-10 depending on density)",
      "items": {
        "type": "object",
        "required": ["id", "name", "description"],
        "properties": {
          "id": {
            "type": "string",
            "description": "Canonical lowercase kebab-case identifier (e.g., 'docker-compose'). REUSE existing IDs when the concept already exists in the graph."
          },
          "name": {
            "type": "string",
            "description": "Human-readable concept name"
          },
          "description": {
            "type": "string",
            "description": "1-3 sentence explanation of the concept"
          },
          "tags": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Optional categorization tags"
          }
        }
      }
    },
    "relationships": {
      "type": "array",
      "description": "Relationships between concepts from THIS document only",
      "items": {
        "type": "object",
        "required": ["id", "fromConceptId", "toConceptId", "label"],
        "properties": {
          "id": {
            "type": "string",
            "description": "Unique relationship identifier"
          },
          "fromConceptId": {
            "type": "string",
            "description": "Source concept ID (must match a concept in this extraction)"
          },
          "toConceptId": {
            "type": "string",
            "description": "Target concept ID (must match a concept in this extraction or existing graph)"
          },
          "label": {
            "type": "string",
            "description": "Relationship type: 'depends on', 'is a type of', 'enables', 'related to'"
          },
          "description": {
            "type": "string",
            "description": "Optional explanation of the relationship"
          }
        }
      }
    },
    "quizItems": {
      "type": "array",
      "description": "Quiz items for spaced repetition (1-3 per concept)",
      "items": {
        "type": "object",
        "required": ["id", "conceptId", "question", "answer"],
        "properties": {
          "id": {
            "type": "string",
            "description": "Unique quiz item identifier"
          },
          "conceptId": {
            "type": "string",
            "description": "Which concept this item tests (must match a concept ID)"
          },
          "question": {
            "type": "string",
            "description": "Clear question testing understanding of the concept"
          },
          "answer": {
            "type": "string",
            "description": "1-3 sentence answer"
          },
          "predictedDifficulty": {
            "type": "number",
            "description": "Claude's estimate of item difficulty (1-10). 1=pure recall of single fact, 5=explain a mechanism, 10=synthesize across many concepts. Used as FSRS initial D₀."
          }
        }
      }
    }
  }
}
```

## Tool: `suggest_sub_concepts`

Used when splitting a parent concept into sub-concepts.

### Input Schema

```json
{
  "type": "object",
  "required": ["subConcepts"],
  "properties": {
    "subConcepts": {
      "type": "array",
      "description": "2-4 sub-concepts splitting the parent into distinct aspects",
      "items": {
        "type": "object",
        "required": ["id", "name", "description", "quizItems"],
        "properties": {
          "id": {
            "type": "string",
            "description": "Extends parent ID (e.g., 'docker-compose-services')"
          },
          "name": {
            "type": "string",
            "description": "Human-readable sub-concept name"
          },
          "description": {
            "type": "string",
            "description": "1-3 sentence explanation"
          },
          "quizItems": {
            "type": "array",
            "description": "1-2 focused quiz items per sub-concept",
            "items": {
              "type": "object",
              "required": ["id", "question", "answer"],
              "properties": {
                "id": { "type": "string" },
                "question": { "type": "string" },
                "answer": { "type": "string" },
                "predictedDifficulty": {
                  "type": "number",
                  "description": "Claude's estimate of item difficulty (1-10). Sub-concepts split from a high-difficulty parent should each be 4-6. Used as FSRS initial D₀."
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## System Prompt for Extraction

```
You are a knowledge extraction assistant. Given a document:

- Extract 3-10 concepts depending on density
- Concept IDs must be canonical lowercase kebab-case (e.g., "docker-compose")
- REUSE existing concept IDs when they appear again (prevents duplicates)
- Create relationships between concepts from THIS document only
- Use "depends on" for prerequisites; other labels for non-prerequisite relationships
- Create 1-3 quiz items per concept
- Use clear, concise language; answers should be 1-3 sentences
```

## System Prompt for Sub-Concept Splitting

```
You are a concept decomposition assistant. Given a parent concept and its quiz item:

- Split into 2-4 sub-concepts, each covering a distinct aspect
- Each sub-concept should be independently understandable
- Sub-concept IDs extend parent (e.g., "docker-compose" -> "docker-compose-services")
- Create 1-2 quiz items per sub-concept
- Use clear, concise language
```

## API Configuration

| Parameter | Value |
|---|---|
| Model | `claude-sonnet-4-5-20250929` (configurable) |
| Max tokens | 16,384 |
| Tool choice | `ToolChoice.tool` (forced) |
| Timeout | 3 minutes per document |
