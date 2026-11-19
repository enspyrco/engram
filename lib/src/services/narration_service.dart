import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:meta/meta.dart';

import 'retry.dart';

/// Summary of a concept for the narration prompt.
@immutable
class ConceptSummary {
  const ConceptSummary({required this.id, required this.name});

  final String id;
  final String name;
}

/// Summary of a relationship for the narration prompt.
@immutable
class RelationshipSummary {
  const RelationshipSummary({
    required this.fromName,
    required this.toName,
    required this.label,
  });

  final String fromName;
  final String toName;
  final String label;
}

const _systemPrompt = '''
You are an educational narrator for a knowledge graph. Given a set of concepts
and their relationships, produce a flowing, conversational narration script that
explains each concept and how they connect.

Rules:
- Wrap every concept mention with [CONCEPT:id]concept text[/CONCEPT] markers.
- Mention EVERY concept at least once using its marker.
- Keep the narration under 90 seconds when read aloud (~225 words).
- Use natural, engaging language — as if explaining to a curious friend.
- Flow logically from foundational concepts to more advanced ones.
- When describing relationships, make the connection clear and intuitive.
- Do NOT include any preamble, headers, or meta-commentary — just the script.
''';

const _toolName = 'generate_narration';

const _narrationTool = Tool.custom(
  name: _toolName,
  description:
      'Generate a concept-annotated narration script for knowledge graph audio.',
  inputSchema: {
    'type': 'object',
    'required': ['annotated_script'],
    'properties': {
      'annotated_script': {
        'type': 'string',
        'description':
            'The narration script with [CONCEPT:id]...[/CONCEPT] markers '
            'around every concept mention. Plain flowing text, no headers.',
      },
    },
  },
);

/// Default model for narration script generation.
const defaultNarrationModel = 'claude-sonnet-4-5-20250929';

/// Generates concept-annotated narration scripts using Claude.
///
/// Follows the same forced-tool-use pattern as [ExtractionService].
/// Takes concept and relationship summaries, returns an annotated script
/// string with `[CONCEPT:id]...[/CONCEPT]` markers ready for
/// [parseConceptMarkers].
class NarrationService {
  NarrationService({
    required String apiKey,
    AnthropicClient? client,
    String model = defaultNarrationModel,
  }) : _client = client ?? AnthropicClient(apiKey: apiKey),
       _model = model;

  final AnthropicClient _client;
  final String _model;

  /// Generate a narration script that mentions all [concepts] with markers.
  ///
  /// Returns the raw annotated script string (e.g.,
  /// `"[CONCEPT:spaced-rep]Spaced repetition[/CONCEPT] is a technique..."`).
  Future<String> generateNarrationScript({
    required List<ConceptSummary> concepts,
    required List<RelationshipSummary> relationships,
  }) async {
    final conceptList = concepts
        .map((c) => '- ${c.name} (id: ${c.id})')
        .join('\n');

    final relationshipList =
        relationships.isEmpty
            ? 'None'
            : relationships
                .map((r) => '- ${r.fromName} --${r.label}--> ${r.toName}')
                .join('\n');

    final response = await retryWithBackoff(
      () => _client.createMessage(
        request: CreateMessageRequest(
          model: Model.modelId(_model),
          maxTokens: 4096,
          system: const CreateMessageRequestSystem.text(_systemPrompt),
          tools: [_narrationTool],
          toolChoice: const ToolChoice(
            type: ToolChoiceType.tool,
            name: _toolName,
          ),
          messages: [
            Message(
              role: MessageRole.user,
              content: MessageContent.text(
                'Generate a narration script for these concepts:\n\n'
                'Concepts:\n$conceptList\n\n'
                'Relationships:\n$relationshipList',
              ),
            ),
          ],
        ),
      ),
    );

    // Extract the tool use block.
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
      throw NarrationException(
        'Claude did not return a tool use block for $_toolName',
      );
    }

    return toolInput['annotated_script'] as String;
  }
}

class NarrationException implements Exception {
  NarrationException(this.message);

  final String message;

  @override
  String toString() => 'NarrationException: $message';
}
