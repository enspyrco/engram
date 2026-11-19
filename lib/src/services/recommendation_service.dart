import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';

import '../models/knowledge_gap.dart';
import '../models/recommendation.dart';
import '../models/relationship.dart';
import 'retry.dart';
import 'outline_client.dart';

const _systemPrompt = '''
You are a knowledge gap analyst. Given a description of a structural gap in a
learner's knowledge graph, plus a set of candidate documents from their wiki,
evaluate how well each document could fill that gap.

Consider:
- Does the document cover topics that bridge the gap?
- Would ingesting it create new connections between existing concepts?
- Is it at the right level (not too basic, not too advanced)?
- Does it introduce concepts that would serve as bridges between clusters?

Be conservative with scores. Only score > 0.7 if the document directly addresses
the gap. Score 0.0 if the document is irrelevant.
''';

const _toolName = 'evaluate_document_gap_fit';

const _evaluationTool = Tool.custom(
  name: _toolName,
  description:
      'Evaluate how well a candidate document would fill a knowledge gap.',
  inputSchema: {
    'type': 'object',
    'required': ['evaluations'],
    'properties': {
      'evaluations': {
        'type': 'array',
        'description': 'One evaluation per candidate document.',
        'items': {
          'type': 'object',
          'required': ['documentId', 'score', 'reasoning'],
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'The ID of the document being evaluated',
            },
            'score': {
              'type': 'number',
              'description':
                  'How well this document fills the gap (0.0 = irrelevant, 1.0 = perfect fit)',
            },
            'reasoning': {
              'type': 'string',
              'description':
                  'Brief explanation of why this document does or does not fill the gap',
            },
            'predictedEdges': {
              'type': 'array',
              'description':
                  'Edges that would likely be created by ingesting this document',
              'items': {
                'type': 'object',
                'required': [
                  'fromConceptName',
                  'toConceptName',
                  'type',
                  'confidence',
                ],
                'properties': {
                  'fromConceptName': {
                    'type': 'string',
                    'description':
                        'Source concept name (may be new or existing)',
                  },
                  'toConceptName': {
                    'type': 'string',
                    'description':
                        'Target concept name (may be new or existing)',
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
                    'description': 'Predicted relationship type',
                  },
                  'confidence': {
                    'type': 'number',
                    'description': 'Confidence in this prediction (0.0–1.0)',
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

/// Default model used for recommendation evaluation.
const defaultRecommendationModel = 'claude-sonnet-4-5-20250929';

/// Service that finds Outline documents to fill knowledge gaps.
///
/// Follows the [ExtractionService] pattern: searches Outline for candidates,
/// then uses Claude with forced tool use to evaluate document–gap fit.
class RecommendationService {
  RecommendationService({
    required this.outlineClient,
    required String apiKey,
    AnthropicClient? anthropicClient,
    String model = defaultRecommendationModel,
  }) : _client = anthropicClient ?? AnthropicClient(apiKey: apiKey),
       _model = model;

  /// The Outline client for searching documents.
  final OutlineClient outlineClient;

  final AnthropicClient _client;
  final String _model;

  /// Find documents that could fill the given knowledge gap.
  ///
  /// Searches Outline using the gap's suggested search terms, filters out
  /// already-ingested documents, then asks Claude to evaluate the candidates.
  Future<List<Recommendation>> recommend({
    required KnowledgeGap gap,
    required List<String> existingConceptNames,
    Set<String> ingestedDocumentIds = const {},
    int maxCandidates = 5,
  }) async {
    // 1. Search Outline using the gap's search terms.
    final candidates = await _searchCandidates(
      gap: gap,
      ingestedDocumentIds: ingestedDocumentIds,
      maxCandidates: maxCandidates,
    );

    if (candidates.isEmpty) return [];

    // 2. Ask Claude to evaluate each candidate against the gap.
    return _evaluateCandidates(
      gap: gap,
      candidates: candidates,
      existingConceptNames: existingConceptNames,
    );
  }

  /// Search Outline for candidate documents, filtering out already-ingested.
  Future<List<_SearchCandidate>> _searchCandidates({
    required KnowledgeGap gap,
    required Set<String> ingestedDocumentIds,
    required int maxCandidates,
  }) async {
    final seen = <String>{};
    final candidates = <_SearchCandidate>[];

    for (final term in gap.suggestedSearchTerms) {
      if (candidates.length >= maxCandidates) break;

      final results = await outlineClient.search(term, limit: maxCandidates);

      for (final result in results) {
        final doc = result['document'] as Map<String, dynamic>;
        final docId = doc['id'] as String;

        // Skip already-ingested or duplicate results.
        if (ingestedDocumentIds.contains(docId) || !seen.add(docId)) continue;

        candidates.add(
          _SearchCandidate(
            documentId: docId,
            title: doc['title'] as String? ?? 'Untitled',
            snippet: result['context'] as String? ?? '',
            collectionId: doc['collectionId'] as String?,
          ),
        );

        if (candidates.length >= maxCandidates) break;
      }
    }

    return candidates;
  }

  /// Use Claude to evaluate how well each candidate fills the gap.
  Future<List<Recommendation>> _evaluateCandidates({
    required KnowledgeGap gap,
    required List<_SearchCandidate> candidates,
    required List<String> existingConceptNames,
  }) async {
    final candidateList = candidates
        .map((c) => '- [${c.documentId}] "${c.title}": ${c.snippet}')
        .join('\n');

    // Truncate to 50 concepts to keep prompt size manageable.
    final truncated = existingConceptNames.take(50).toList();
    final conceptList = truncated.join(', ');
    final truncationNote =
        existingConceptNames.length > 50
            ? ' (showing 50 of ${existingConceptNames.length})'
            : '';

    final response = await retryWithBackoff(
      () => _client.createMessage(
        request: CreateMessageRequest(
          model: Model.modelId(_model),
          maxTokens: 4096,
          system: const CreateMessageRequestSystem.text(_systemPrompt),
          tools: [_evaluationTool],
          toolChoice: const ToolChoice(
            type: ToolChoiceType.tool,
            name: _toolName,
          ),
          messages: [
            Message(
              role: MessageRole.user,
              content: MessageContent.text(
                'Evaluate these documents for filling a knowledge gap.\n\n'
                '## Gap\n'
                'Type: ${gap.type.name}\n'
                'Description: ${gap.description}\n\n'
                '## Existing concepts in the graph$truncationNote\n'
                '$conceptList\n\n'
                '## Candidate documents\n'
                '$candidateList',
              ),
            ),
          ],
        ),
      ),
    );

    // Extract tool use block.
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
      throw RecommendationException(
        'Claude did not return a tool use block for $_toolName',
      );
    }

    return _parseEvaluations(toolInput, gap, candidates);
  }

  List<Recommendation> _parseEvaluations(
    Map<String, dynamic> input,
    KnowledgeGap gap,
    List<_SearchCandidate> candidates,
  ) {
    final evaluations = input['evaluations'] as List<dynamic>? ?? [];
    final candidateMap = {for (final c in candidates) c.documentId: c};

    final recommendations = <Recommendation>[];
    for (final eval in evaluations) {
      final map = eval as Map<String, dynamic>;
      final docId = map['documentId'] as String;
      final score = (map['score'] as num).toDouble();
      final reasoning = map['reasoning'] as String;

      // Skip low-score recommendations.
      if (score < 0.1) continue;

      final candidate = candidateMap[docId];
      if (candidate == null) continue;

      final predictedEdges = <PredictedEdge>[];
      final edgeList = map['predictedEdges'] as List<dynamic>? ?? [];
      for (final e in edgeList) {
        final edgeMap = e as Map<String, dynamic>;
        predictedEdges.add(
          PredictedEdge(
            fromConceptName: edgeMap['fromConceptName'] as String,
            toConceptName: edgeMap['toConceptName'] as String,
            type:
                RelationshipType.tryParse(edgeMap['type'] as String? ?? '') ??
                RelationshipType.relatedTo,
            confidence: (edgeMap['confidence'] as num).toDouble(),
          ),
        );
      }

      recommendations.add(
        Recommendation(
          documentId: docId,
          documentTitle: candidate.title,
          gap: gap,
          score: score,
          reasoning: reasoning,
          predictedNewEdges: predictedEdges,
          searchSnippet: candidate.snippet,
          collectionId: candidate.collectionId,
        ),
      );
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations;
  }
}

/// Internal search result before Claude evaluation.
class _SearchCandidate {
  const _SearchCandidate({
    required this.documentId,
    required this.title,
    required this.snippet,
    this.collectionId,
  });

  final String documentId;
  final String title;
  final String snippet;
  final String? collectionId;
}

class RecommendationException implements Exception {
  RecommendationException(this.message);

  final String message;

  @override
  String toString() => 'RecommendationException: $message';
}
