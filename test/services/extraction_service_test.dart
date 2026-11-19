import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:engram/src/engine/difficulty_evaluation.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/services/extraction_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAnthropicClient extends Mock implements AnthropicClient {}

class FakeCreateMessageRequest extends Fake implements CreateMessageRequest {}

/// Helper to build a Message with a tool use block containing the given input.
Message _toolUseMessage(Map<String, dynamic> input) {
  return Message(
    id: 'msg-test',
    role: MessageRole.assistant,
    stopReason: StopReason.toolUse,
    content: MessageContent.blocks([
      Block.toolUse(id: 'tu-1', name: 'extract_knowledge', input: input),
    ]),
    model: 'claude-sonnet-4-5-20250929',
    type: 'message',
    usage: const Usage(inputTokens: 10, outputTokens: 10),
  );
}

void main() {
  late MockAnthropicClient mockClient;
  late ExtractionService service;

  setUpAll(() {
    registerFallbackValue(FakeCreateMessageRequest());
  });

  setUp(() {
    mockClient = MockAnthropicClient();
    service = ExtractionService(apiKey: 'test-key', client: mockClient);
  });

  group('ExtractionService cross-document relationships', () {
    test('preserves relationships referencing existing concept IDs', () async {
      // Claude returns a concept "new-concept" and a relationship from
      // "new-concept" to "existing-concept" (which is already in the graph).
      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _toolUseMessage({
          'concepts': [
            {
              'id': 'new-concept',
              'name': 'New Concept',
              'description': 'A newly extracted concept',
            },
          ],
          'relationships': [
            {
              'id': 'r1',
              'fromConceptId': 'new-concept',
              'toConceptId': 'existing-concept',
              'label': 'depends on',
            },
          ],
          'quizItems': [
            {
              'id': 'q1',
              'conceptId': 'new-concept',
              'question': 'What is new concept?',
              'answer': 'A newly extracted concept.',
            },
          ],
        }),
      );

      final result = await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
        existingConceptIds: ['existing-concept', 'other-concept'],
      );

      expect(result.concepts, hasLength(1));
      expect(result.relationships, hasLength(1));
      expect(result.relationships.first.fromConceptId, 'new-concept');
      expect(result.relationships.first.toConceptId, 'existing-concept');
    });

    test('drops relationships referencing unknown concept IDs', () async {
      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _toolUseMessage({
          'concepts': [
            {'id': 'c1', 'name': 'Concept 1', 'description': 'Desc'},
          ],
          'relationships': [
            {
              'id': 'r1',
              'fromConceptId': 'c1',
              'toConceptId': 'totally-unknown',
              'label': 'depends on',
            },
          ],
          'quizItems': [],
        }),
      );

      final result = await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
      );

      expect(result.relationships, isEmpty);
    });

    test('allows relationships between two existing concept IDs', () async {
      // Claude might create a relationship between two concepts already in
      // the graph (neither is newly extracted in this document).
      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _toolUseMessage({
          'concepts': [
            {
              'id': 'new-concept',
              'name': 'New',
              'description': 'Newly extracted',
            },
          ],
          'relationships': [
            {
              'id': 'r1',
              'fromConceptId': 'existing-a',
              'toConceptId': 'existing-b',
              'label': 'related to',
            },
          ],
          'quizItems': [],
        }),
      );

      final result = await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
        existingConceptIds: ['existing-a', 'existing-b'],
      );

      expect(result.relationships, hasLength(1));
      expect(result.relationships.first.fromConceptId, 'existing-a');
      expect(result.relationships.first.toConceptId, 'existing-b');
    });

    test('quiz items referencing existing concepts are preserved', () async {
      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _toolUseMessage({
          'concepts': [],
          'relationships': [],
          'quizItems': [
            {
              'id': 'q1',
              'conceptId': 'existing-concept',
              'question': 'Review question',
              'answer': 'Review answer',
              'predictedDifficulty': 4,
            },
          ],
        }),
      );

      final result = await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
        existingConceptIds: ['existing-concept'],
      );

      expect(result.quizItems, hasLength(1));
      expect(result.quizItems.first.conceptId, 'existing-concept');
    });

    test('quiz items referencing unknown concepts are dropped', () async {
      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _toolUseMessage({
          'concepts': [
            {'id': 'c1', 'name': 'C1', 'description': 'Desc'},
          ],
          'relationships': [],
          'quizItems': [
            {
              'id': 'q1',
              'conceptId': 'c1',
              'question': 'Q valid?',
              'answer': 'Yes.',
            },
            {
              'id': 'q2',
              'conceptId': 'orphan-id',
              'question': 'Q orphan?',
              'answer': 'Should be dropped.',
            },
          ],
        }),
      );

      final result = await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
      );

      expect(result.quizItems, hasLength(1));
      expect(result.quizItems.first.id, 'q1');
    });

    test(
      'without existing IDs, only intra-document relationships pass',
      () async {
        when(
          () => mockClient.createMessage(request: any(named: 'request')),
        ).thenAnswer(
          (_) async => _toolUseMessage({
            'concepts': [
              {'id': 'c1', 'name': 'C1', 'description': 'D1'},
              {'id': 'c2', 'name': 'C2', 'description': 'D2'},
            ],
            'relationships': [
              {
                'id': 'r1',
                'fromConceptId': 'c1',
                'toConceptId': 'c2',
                'label': 'depends on',
              },
              {
                'id': 'r2',
                'fromConceptId': 'c1',
                'toConceptId': 'external',
                'label': 'related to',
              },
            ],
            'quizItems': [],
          }),
        );

        final result = await service.extract(
          documentTitle: 'Test Doc',
          documentContent: 'Test content',
          // No existing IDs — so 'external' is unknown
        );

        expect(result.relationships, hasLength(1));
        expect(result.relationships.first.id, 'r1');
      },
    );
  });

  group('ExtractionService typed relationships', () {
    test('parses explicit type from extraction result', () async {
      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer(
        (_) async => _toolUseMessage({
          'concepts': [
            {'id': 'c1', 'name': 'C1', 'description': 'D1'},
            {'id': 'c2', 'name': 'C2', 'description': 'D2'},
          ],
          'relationships': [
            {
              'id': 'r1',
              'fromConceptId': 'c1',
              'toConceptId': 'c2',
              'label': 'depends on',
              'type': 'prerequisite',
            },
            {
              'id': 'r2',
              'fromConceptId': 'c1',
              'toConceptId': 'c2',
              'label': 'is a type of',
              'type': 'generalization',
            },
            {
              'id': 'r3',
              'fromConceptId': 'c1',
              'toConceptId': 'c2',
              'label': 'analogous to',
              'type': 'analogy',
            },
          ],
          'quizItems': [],
        }),
      );

      final result = await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
      );

      expect(result.relationships, hasLength(3));
      expect(result.relationships[0].type, RelationshipType.prerequisite);
      expect(result.relationships[1].type, RelationshipType.generalization);
      expect(result.relationships[2].type, RelationshipType.analogy);
    });

    test(
      'handles missing type field gracefully (falls back to inference)',
      () async {
        when(
          () => mockClient.createMessage(request: any(named: 'request')),
        ).thenAnswer(
          (_) async => _toolUseMessage({
            'concepts': [
              {'id': 'c1', 'name': 'C1', 'description': 'D1'},
              {'id': 'c2', 'name': 'C2', 'description': 'D2'},
            ],
            'relationships': [
              {
                'id': 'r1',
                'fromConceptId': 'c1',
                'toConceptId': 'c2',
                'label': 'enables',
                // no 'type' field
              },
            ],
            'quizItems': [],
          }),
        );

        final result = await service.extract(
          documentTitle: 'Test Doc',
          documentContent: 'Test content',
        );

        expect(result.relationships, hasLength(1));
        expect(result.relationships.first.type, isNull);
        expect(
          result.relationships.first.resolvedType,
          RelationshipType.enables,
        );
      },
    );
  });

  group('ExtractionService calibration feedback', () {
    test(
      'includes calibration note when predictionAccuracy is provided',
      () async {
        CreateMessageRequest? capturedRequest;

        when(
          () => mockClient.createMessage(request: any(named: 'request')),
        ).thenAnswer((invocation) async {
          capturedRequest =
              invocation.namedArguments[#request] as CreateMessageRequest;
          return _toolUseMessage({
            'concepts': [],
            'relationships': [],
            'quizItems': [],
          });
        });

        const evaluation = DifficultyEvaluationResult(
          evaluatedCount: 10,
          totalPredicted: 15,
          meanAbsoluteError: 1.5,
          bandAccuracy: {
            'low': BandAccuracy(correct: 3, predicted: 4),
            'medium': BandAccuracy(correct: 4, predicted: 5),
            'high': BandAccuracy(correct: 0, predicted: 1),
          },
        );

        await service.extract(
          documentTitle: 'Test Doc',
          documentContent: 'Test content',
          predictionAccuracy: evaluation,
        );

        expect(capturedRequest, isNotNull);
        final message = capturedRequest!.messages.first;
        final text = (message.content as MessageContentText).value;

        expect(text, contains('Difficulty calibration'));
        expect(text, contains('10 cards'));
        expect(text, contains('1.5'));
        expect(text, contains('Low band (1-3): 3/4 correct'));
        expect(text, contains('Medium band (4-6): 4/5 correct'));
        expect(text, contains('High band (7-10): 0/1 correct'));
      },
    );

    test('omits calibration note when predictionAccuracy is null', () async {
      CreateMessageRequest? capturedRequest;

      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer((invocation) async {
        capturedRequest =
            invocation.namedArguments[#request] as CreateMessageRequest;
        return _toolUseMessage({
          'concepts': [],
          'relationships': [],
          'quizItems': [],
        });
      });

      await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
      );

      expect(capturedRequest, isNotNull);
      final message = capturedRequest!.messages.first;
      final text = (message.content as MessageContentText).value;
      expect(text, isNot(contains('Difficulty calibration')));
    });

    test('omits calibration note when evaluatedCount is 0', () async {
      CreateMessageRequest? capturedRequest;

      when(
        () => mockClient.createMessage(request: any(named: 'request')),
      ).thenAnswer((invocation) async {
        capturedRequest =
            invocation.namedArguments[#request] as CreateMessageRequest;
        return _toolUseMessage({
          'concepts': [],
          'relationships': [],
          'quizItems': [],
        });
      });

      await service.extract(
        documentTitle: 'Test Doc',
        documentContent: 'Test content',
        predictionAccuracy: DifficultyEvaluationResult.empty(),
      );

      expect(capturedRequest, isNotNull);
      final message = capturedRequest!.messages.first;
      final text = (message.content as MessageContentText).value;
      expect(text, isNot(contains('Difficulty calibration')));
    });
  });
}
