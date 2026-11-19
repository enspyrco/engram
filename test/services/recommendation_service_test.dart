import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:engram/src/models/knowledge_gap.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/services/outline_client.dart';
import 'package:engram/src/services/recommendation_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAnthropicClient extends Mock implements AnthropicClient {}

class FakeCreateMessageRequest extends Fake implements CreateMessageRequest {}

/// Build an Outline MockClient that returns fixed search results.
OutlineClient _outlineClient(List<Map<String, dynamic>> searchResults) {
  final mockHttp = MockClient((request) async {
    return http.Response(jsonEncode({'data': searchResults}), 200);
  });
  return OutlineClient(
    apiUrl: 'https://wiki.example.com',
    apiKey: 'test-key',
    httpClient: mockHttp,
  );
}

/// Build a Claude tool use response for the evaluate_document_gap_fit tool.
Message _evaluationMessage(Map<String, dynamic> input) {
  return Message(
    id: 'msg-test',
    role: MessageRole.assistant,
    stopReason: StopReason.toolUse,
    content: MessageContent.blocks([
      Block.toolUse(
        id: 'tu-1',
        name: 'evaluate_document_gap_fit',
        input: input,
      ),
    ]),
    model: 'claude-sonnet-4-5-20250929',
    type: 'message',
    usage: const Usage(inputTokens: 10, outputTokens: 10),
  );
}

void main() {
  late MockAnthropicClient mockClaude;

  final testGap = KnowledgeGap(
    type: GapType.clusterIsolation,
    description: 'ML and Databases are disconnected',
    severity: 0.8,
    bridgePotential: 0.9,
    involvedConceptIds: ['ml', 'db'],
    involvedClusterLabels: ['Machine Learning', 'Databases'],
    suggestedSearchTerms: ['machine learning', 'database'],
  );

  setUpAll(() {
    registerFallbackValue(FakeCreateMessageRequest());
  });

  setUp(() {
    mockClaude = MockAnthropicClient();
  });

  group('RecommendationService', () {
    test('returns recommendations sorted by score', () async {
      final outlineClient = _outlineClient([
        {
          'document': {'id': 'doc-1', 'title': 'ML for DBAs'},
          'context': 'Applying ML to database optimization...',
        },
        {
          'document': {'id': 'doc-2', 'title': 'SQL Basics'},
          'context': 'SQL is a query language...',
        },
      ]);

      when(
        () => mockClaude.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _evaluationMessage({
          'evaluations': [
            {
              'documentId': 'doc-1',
              'score': 0.9,
              'reasoning': 'Directly bridges ML and databases',
              'predictedEdges': [
                {
                  'fromConceptName': 'ML Optimization',
                  'toConceptName': 'Query Planning',
                  'type': 'enables',
                  'confidence': 0.8,
                },
              ],
            },
            {
              'documentId': 'doc-2',
              'score': 0.3,
              'reasoning': 'Only covers SQL basics, weak bridge',
              'predictedEdges': [],
            },
          ],
        }),
      );

      final service = RecommendationService(
        outlineClient: outlineClient,
        apiKey: 'test-key',
        anthropicClient: mockClaude,
      );

      final recs = await service.recommend(
        gap: testGap,
        existingConceptNames: ['Neural Networks', 'SQL'],
      );

      expect(recs, hasLength(2));
      expect(recs[0].documentId, 'doc-1');
      expect(recs[0].score, 0.9);
      expect(recs[0].predictedNewEdges, hasLength(1));
      expect(recs[0].predictedNewEdges.first.type, RelationshipType.enables);
      expect(recs[1].documentId, 'doc-2');
      expect(recs[1].score, 0.3);
    });

    test('filters out already-ingested documents', () async {
      final outlineClient = _outlineClient([
        {
          'document': {'id': 'already-ingested', 'title': 'Old Doc'},
          'context': 'Already in the graph...',
        },
        {
          'document': {'id': 'new-doc', 'title': 'New Doc'},
          'context': 'Fresh content...',
        },
      ]);

      when(
        () => mockClaude.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _evaluationMessage({
          'evaluations': [
            {'documentId': 'new-doc', 'score': 0.7, 'reasoning': 'Good fit'},
          ],
        }),
      );

      final service = RecommendationService(
        outlineClient: outlineClient,
        apiKey: 'test-key',
        anthropicClient: mockClaude,
      );

      final recs = await service.recommend(
        gap: testGap,
        existingConceptNames: ['Concept A'],
        ingestedDocumentIds: {'already-ingested'},
      );

      expect(recs, hasLength(1));
      expect(recs[0].documentId, 'new-doc');
    });

    test('returns empty list when no search results', () async {
      final outlineClient = _outlineClient([]);

      final service = RecommendationService(
        outlineClient: outlineClient,
        apiKey: 'test-key',
        anthropicClient: mockClaude,
      );

      final recs = await service.recommend(
        gap: testGap,
        existingConceptNames: [],
      );

      expect(recs, isEmpty);
      // Claude should not be called when no candidates.
      verifyNever(
        () => mockClaude.createMessage(request: any(named: 'request')),
      );
    });

    test('filters out low-score evaluations (< 0.1)', () async {
      final outlineClient = _outlineClient([
        {
          'document': {'id': 'doc-1', 'title': 'Irrelevant'},
          'context': 'Not relevant...',
        },
      ]);

      when(
        () => mockClaude.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _evaluationMessage({
          'evaluations': [
            {
              'documentId': 'doc-1',
              'score': 0.05,
              'reasoning': 'Completely irrelevant',
            },
          ],
        }),
      );

      final service = RecommendationService(
        outlineClient: outlineClient,
        apiKey: 'test-key',
        anthropicClient: mockClaude,
      );

      final recs = await service.recommend(
        gap: testGap,
        existingConceptNames: [],
      );

      expect(recs, isEmpty);
    });

    test('throws RecommendationException when no tool use block', () async {
      final outlineClient = _outlineClient([
        {
          'document': {'id': 'doc-1', 'title': 'Some Doc'},
          'context': 'Content...',
        },
      ]);

      when(
        () => mockClaude.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => const Message(
          id: 'msg-test',
          role: MessageRole.assistant,
          stopReason: StopReason.endTurn,
          content: MessageContent.blocks([
            Block.text(text: 'I cannot evaluate these documents.'),
          ]),
          model: 'claude-sonnet-4-5-20250929',
          type: 'message',
          usage: Usage(inputTokens: 10, outputTokens: 10),
        ),
      );

      final service = RecommendationService(
        outlineClient: outlineClient,
        apiKey: 'test-key',
        anthropicClient: mockClaude,
      );

      expect(
        () => service.recommend(gap: testGap, existingConceptNames: []),
        throwsA(isA<RecommendationException>()),
      );
    });
  });
}
