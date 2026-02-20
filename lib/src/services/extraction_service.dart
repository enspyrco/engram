import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';

import '../models/concept.dart';
import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import '../models/sub_concept_suggestion.dart';

const _systemPrompt = '''
You are a knowledge extraction engine. Given a wiki document, extract:
1. **Concepts**: Key ideas, terms, entities, or principles. Each gets a unique ID.
2. **Relationships**: How concepts connect, using typed relationships.
3. **Quiz items**: Flashcard-style questions that test understanding of each concept.

Guidelines:
- Extract all significant concepts. Let document density guide quantity — a brief glossary may yield 2-3, a dense technical article may yield 15-20. Favor precision over volume.
- Concept IDs must be canonical lowercase kebab-case based on the concept name (e.g. "docker-compose", "dependency-injection"). If existing concept IDs are provided, reuse them for the same concepts instead of creating new IDs.
- Create relationships between concepts. You may reference existing concept IDs to build cross-document connections.
- Each relationship must have a `type` from this taxonomy:
  - `prerequisite`: A cannot be understood without B. Drives concept unlocking order.
  - `generalization`: A is a subtype or specific instance of B.
  - `composition`: A is a component or part of B.
  - `enables`: A makes B possible or practical, but B can be understood without A.
  - `analogy`: Cross-discipline semantic similarity between A and B.
  - `contrast`: Explicit difference between similar concepts A and B.
  - `relatedTo`: General association when no other type fits. Use sparingly.
- The `label` field should be a natural-language description (e.g. "depends on", "is a type of"), while `type` is the canonical enum value.
- Create 1-3 quiz items per concept. Questions should test understanding, not just recall.
- Use clear, concise language. Answers should be 1-3 sentences.
- For each quiz item, predict its difficulty on a 1-10 scale:
  1-3 = pure fact recall, single prerequisite or none
  4-6 = explain a mechanism or process, 2-3 prerequisites
  7-10 = synthesize across multiple concepts, abstract reasoning
''';

const _toolName = 'extract_knowledge';

const _extractionTool = Tool.custom(
  name: _toolName,
  description:
      'Extract structured knowledge (concepts, relationships, quiz items) from a document.',
  inputSchema: {
    'type': 'object',
    'required': ['concepts', 'relationships', 'quizItems'],
    'properties': {
      'concepts': {
        'type': 'array',
        'description': 'Key concepts extracted from the document.',
        'items': {
          'type': 'object',
          'required': ['id', 'name', 'description'],
          'properties': {
            'id': {
              'type': 'string',
              'description':
                  'Unique ID in kebab-case, e.g. "dependency-injection"',
            },
            'name': {
              'type': 'string',
              'description': 'Human-readable concept name',
            },
            'description': {
              'type': 'string',
              'description': '1-3 sentence description of the concept',
            },
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Optional categorization tags',
            },
          },
        },
      },
      'relationships': {
        'type': 'array',
        'description': 'How concepts relate to each other.',
        'items': {
          'type': 'object',
          'required': [
            'id',
            'fromConceptId',
            'toConceptId',
            'label',
            'type',
          ],
          'properties': {
            'id': {
              'type': 'string',
              'description': 'Unique relationship ID',
            },
            'fromConceptId': {
              'type': 'string',
              'description': 'Source concept ID',
            },
            'toConceptId': {
              'type': 'string',
              'description': 'Target concept ID',
            },
            'label': {
              'type': 'string',
              'description':
                  'Natural-language description, e.g. "depends on", "enables", "is a type of"',
            },
            'type': {
              'type': 'string',
              'enum': [
                'prerequisite',
                'generalization',
                'composition',
                'enables',
                'analogy',
                'contrast',
                'relatedTo',
              ],
              'description': 'The semantic type of the relationship',
            },
            'description': {
              'type': 'string',
              'description': 'Optional description of the relationship',
            },
          },
        },
      },
      'quizItems': {
        'type': 'array',
        'description': 'Flashcard-style questions testing understanding.',
        'items': {
          'type': 'object',
          'required': ['id', 'conceptId', 'question', 'answer'],
          'properties': {
            'id': {
              'type': 'string',
              'description': 'Unique quiz item ID',
            },
            'conceptId': {
              'type': 'string',
              'description': 'ID of the concept being tested',
            },
            'question': {
              'type': 'string',
              'description': 'The question to ask',
            },
            'answer': {
              'type': 'string',
              'description': 'The expected answer (1-3 sentences)',
            },
            'predictedDifficulty': {
              'type': 'number',
              'description':
                  'Predicted difficulty (1-10). 1=single fact recall, 5=mechanism, 10=synthesis across concepts. Used as FSRS initial D₀.',
            },
          },
        },
      },
    },
  },
);

const _splitSystemPrompt = '''
You are a knowledge decomposition engine. Given a concept and its quiz question/answer, suggest how to split it into smaller, independently masterable sub-concepts.

Guidelines:
- Split into 2-4 sub-concepts, each covering a distinct aspect.
- Each sub-concept should be independently understandable and testable.
- Sub-concept IDs must extend the parent ID (e.g. parent "docker-compose" → children "docker-compose-services", "docker-compose-volumes").
- Create 1-2 quiz items per sub-concept that test understanding of that specific aspect.
- Use clear, concise language. Answers should be 1-3 sentences.
- Sub-concept items should have difficulty in the 4-6 range, as they decompose complex concepts into manageable pieces.
''';

const _splitToolName = 'suggest_sub_concepts';

const _splitTool = Tool.custom(
  name: _splitToolName,
  description:
      'Suggest how to split a concept into smaller sub-concepts with quiz items.',
  inputSchema: {
    'type': 'object',
    'required': ['subConcepts'],
    'properties': {
      'subConcepts': {
        'type': 'array',
        'description': 'The suggested sub-concepts.',
        'items': {
          'type': 'object',
          'required': ['id', 'name', 'description', 'quizItems'],
          'properties': {
            'id': {
              'type': 'string',
              'description':
                  'Unique ID extending the parent ID, e.g. "parent-id-aspect"',
            },
            'name': {
              'type': 'string',
              'description': 'Human-readable sub-concept name',
            },
            'description': {
              'type': 'string',
              'description': '1-3 sentence description',
            },
            'quizItems': {
              'type': 'array',
              'description': 'Quiz items for this sub-concept.',
              'items': {
                'type': 'object',
                'required': ['id', 'question', 'answer'],
                'properties': {
                  'id': {
                    'type': 'string',
                    'description': 'Unique quiz item ID',
                  },
                  'question': {
                    'type': 'string',
                    'description': 'The question to ask',
                  },
                  'answer': {
                    'type': 'string',
                    'description': 'The expected answer (1-3 sentences)',
                  },
                  'predictedDifficulty': {
                    'type': 'number',
                    'description':
                        'Predicted difficulty (1-10). Sub-concept items should target 4-6.',
                  },
                },
              },
            },
          },
        },
      },
    },
  },
);

/// Default model used for extraction and sub-concept splitting.
const defaultExtractionModel = 'claude-sonnet-4-5-20250929';

class ExtractionService {
  ExtractionService({
    required String apiKey,
    AnthropicClient? client,
    String model = defaultExtractionModel,
  })  : _client = client ?? AnthropicClient(apiKey: apiKey),
        _model = model;

  final AnthropicClient _client;
  final String _model;

  Future<ExtractionResult> extract({
    required String documentTitle,
    required String documentContent,
    List<String> existingConceptIds = const [],
  }) async {
    final existingIdsNote = existingConceptIds.isNotEmpty
        ? '\n\nExisting concept IDs in the knowledge graph (reuse these '
            'when referring to the same concepts):\n'
            '${existingConceptIds.join(', ')}\n'
        : '';

    final response = await _client.createMessage(
      request: CreateMessageRequest(
        model: Model.modelId(_model),
        maxTokens: 16384,
        system: const CreateMessageRequestSystem.text(_systemPrompt),
        tools: [_extractionTool],
        toolChoice: const ToolChoice(
          type: ToolChoiceType.tool,
          name: _toolName,
        ),
        messages: [
          Message(
            role: MessageRole.user,
            content: MessageContent.text(
              'Extract knowledge from this document.'
              '$existingIdsNote\n\n'
              '# $documentTitle\n\n'
              '$documentContent',
            ),
          ),
        ],
      ),
    );

    // Find the tool use block
    final content = response.content;
    Map<String, dynamic>? toolInput;

    if (content case MessageContentBlocks(value: final blocks)) {
      for (final block in blocks) {
        if (block case ToolUseBlock(name: _toolName, :final input)) {
          toolInput = input;
          break;
        }
      }
    }

    if (toolInput == null) {
      throw ExtractionException(
        'Claude did not return a tool use block for $_toolName',
      );
    }

    return _parseResult(
      toolInput,
      documentTitle,
      existingConceptIds: existingConceptIds.toSet(),
    );
  }

  /// Ask Claude to suggest sub-concepts for splitting a parent concept.
  Future<SubConceptSuggestion> generateSubConcepts({
    required String parentConceptId,
    required String parentName,
    required String parentDescription,
    required String quizQuestion,
    required String quizAnswer,
    required String sourceDocumentId,
  }) async {
    final response = await _client.createMessage(
      request: CreateMessageRequest(
        model: Model.modelId(_model),
        maxTokens: 4096,
        system: const CreateMessageRequestSystem.text(_splitSystemPrompt),
        tools: [_splitTool],
        toolChoice: const ToolChoice(
          type: ToolChoiceType.tool,
          name: _splitToolName,
        ),
        messages: [
          Message(
            role: MessageRole.user,
            content: MessageContent.text(
              'Split this concept into sub-concepts.\n\n'
              'Concept ID: $parentConceptId\n'
              'Concept name: $parentName\n'
              'Description: $parentDescription\n\n'
              'Quiz question: $quizQuestion\n'
              'Quiz answer: $quizAnswer',
            ),
          ),
        ],
      ),
    );

    // Find the tool use block
    final content = response.content;
    Map<String, dynamic>? toolInput;

    if (content case MessageContentBlocks(value: final blocks)) {
      for (final block in blocks) {
        if (block case ToolUseBlock(name: _splitToolName, :final input)) {
          toolInput = input;
          break;
        }
      }
    }

    if (toolInput == null) {
      throw ExtractionException(
        'Claude did not return a tool use block for $_splitToolName',
      );
    }

    return _parseSplitResult(toolInput, parentConceptId, sourceDocumentId);
  }

  SubConceptSuggestion _parseSplitResult(
    Map<String, dynamic> input,
    String parentConceptId,
    String sourceDocumentId,
  ) {
    final subConcepts = input['subConcepts'] as List<dynamic>? ?? [];

    final entries = <SubConceptEntry>[];
    for (final sc in subConcepts) {
      final map = sc as Map<String, dynamic>;
      final conceptId = map['id'] as String;

      final concept = Concept(
        id: conceptId,
        name: map['name'] as String,
        description: map['description'] as String,
        sourceDocumentId: sourceDocumentId,
        parentConceptId: parentConceptId,
      );

      final quizItemsList = map['quizItems'] as List<dynamic>? ?? [];
      final quizItems = quizItemsList.map((q) {
        final qMap = q as Map<String, dynamic>;
        return QuizItem.newCard(
          id: qMap['id'] as String,
          conceptId: conceptId,
          question: qMap['question'] as String,
          answer: qMap['answer'] as String,
          predictedDifficulty:
              (qMap['predictedDifficulty'] as num?)?.toDouble(),
        );
      }).toList();

      entries.add(SubConceptEntry(concept: concept, quizItems: quizItems));
    }

    return SubConceptSuggestion(entries: entries);
  }

  ExtractionResult _parseResult(
    Map<String, dynamic> input,
    String documentTitle, {
    Set<String> existingConceptIds = const {},
  }) {
    final conceptsList = input['concepts'] as List<dynamic>? ?? [];
    final relationshipsList = input['relationships'] as List<dynamic>? ?? [];
    final quizItemsList = input['quizItems'] as List<dynamic>? ?? [];

    // Build a set of valid concept IDs: newly extracted + existing graph
    final extractedIds = <String>{};

    final concepts = conceptsList.map((c) {
      final map = c as Map<String, dynamic>;
      final id = map['id'] as String;
      extractedIds.add(id);
      return Concept(
        id: id,
        name: map['name'] as String,
        description: map['description'] as String,
        sourceDocumentId: '', // Will be set by caller via withNewExtraction
        tags: (map['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
    }).toList();

    final validIds = {...extractedIds, ...existingConceptIds};

    final relationships = <Relationship>[];
    for (final r in relationshipsList) {
      final map = r as Map<String, dynamic>;
      final fromId = map['fromConceptId'] as String;
      final toId = map['toConceptId'] as String;

      // Skip relationships with orphaned concept references
      if (!validIds.contains(fromId) || !validIds.contains(toId)) {
        continue;
      }

      relationships.add(Relationship(
        id: map['id'] as String,
        fromConceptId: fromId,
        toConceptId: toId,
        label: map['label'] as String,
        description: map['description'] as String?,
        type: switch (map['type'] as String?) {
          final s? => RelationshipType.tryParse(s),
          null => null,
        },
      ));
    }

    final quizItems = <QuizItem>[];
    for (final q in quizItemsList) {
      final map = q as Map<String, dynamic>;
      final conceptId = map['conceptId'] as String;

      if (!validIds.contains(conceptId)) {
        continue;
      }

      quizItems.add(QuizItem.newCard(
        id: map['id'] as String,
        conceptId: conceptId,
        question: map['question'] as String,
        answer: map['answer'] as String,
        predictedDifficulty: (map['predictedDifficulty'] as num?)?.toDouble(),
      ));
    }

    return ExtractionResult(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems,
    );
  }
}

class ExtractionException implements Exception {
  ExtractionException(this.message);

  final String message;

  @override
  String toString() => 'ExtractionException: $message';
}
