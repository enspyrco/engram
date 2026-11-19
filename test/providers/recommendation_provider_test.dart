import 'dart:convert';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_gap.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/recommendation.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/recommendation_provider.dart';
import 'package:engram/src/providers/service_providers.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/services/extraction_service.dart';
import 'package:engram/src/services/outline_client.dart';
import 'package:engram/src/storage/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class MockExtractionService extends Mock implements ExtractionService {}

void main() {
  group('RecommendationNotifier.ingestRecommendation', () {
    late MockExtractionService mockExtraction;
    late SharedPreferences prefs;
    late SettingsRepository settingsRepo;

    final testGap = KnowledgeGap(
      type: GapType.clusterIsolation,
      description: 'ML and DB are disconnected',
      severity: 0.8,
      bridgePotential: 0.9,
    );

    setUp(() async {
      mockExtraction = MockExtractionService();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      settingsRepo = SettingsRepository(prefs);
    });

    ProviderContainer createContainer({
      required http.Client httpClient,
      KnowledgeGraph? initialGraph,
    }) {
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          knowledgeGraphProvider.overrideWith(
            () => _InMemoryGraphNotifier(initialGraph),
          ),
          outlineClientProvider.overrideWithValue(
            OutlineClient(
              apiUrl: 'https://wiki.test.com',
              apiKey: 'test-key',
              httpClient: httpClient,
            ),
          ),
          extractionServiceProvider.overrideWithValue(mockExtraction),
        ],
      );
    }

    test(
      'happy path: transitions ingesting → evaluating → completed',
      () async {
        final httpClient = MockClient((request) async {
          if (request.url.path == '/api/documents.info') {
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'doc-1',
                  'title': 'ML for DBAs',
                  'text': '# ML for DBAs\nContent here.',
                  'collectionId': 'col-1',
                },
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });

        final initialGraph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'ml',
              name: 'ML',
              description: 'Machine Learning',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'sql',
              name: 'SQL',
              description: 'Structured Query Language',
              sourceDocumentId: 'd',
            ),
          ],
        );

        when(
          () => mockExtraction.extract(
            documentTitle: any(named: 'documentTitle'),
            documentContent: any(named: 'documentContent'),
            existingConceptIds: any(named: 'existingConceptIds'),
            predictionAccuracy: any(named: 'predictionAccuracy'),
          ),
        ).thenAnswer(
          (_) async => ExtractionResult(
            concepts: [
              Concept(
                id: 'ml-db',
                name: 'ML Database Integration',
                description: 'Using ML with databases',
                sourceDocumentId: '',
              ),
            ],
            relationships: const [
              Relationship(
                id: 'r1',
                fromConceptId: 'ml',
                toConceptId: 'ml-db',
                label: 'enables',
                type: RelationshipType.enables,
              ),
            ],
            quizItems: const [],
          ),
        );

        final container = createContainer(
          httpClient: httpClient,
          initialGraph: initialGraph,
        );
        await container.read(knowledgeGraphProvider.future);

        final rec = Recommendation(
          documentId: 'doc-1',
          documentTitle: 'ML for DBAs',
          gap: testGap,
          score: 0.85,
          reasoning: 'Bridges gap',
          predictedNewEdges: const [
            PredictedEdge(
              fromConceptName: 'ML',
              toConceptName: 'ML Database Integration',
              type: RelationshipType.enables,
              confidence: 0.8,
            ),
          ],
        );

        // Track status transitions.
        final statuses = <RecommendationIngestStatus>[];
        container.listen(recommendationProvider, (prev, next) {
          final result = next.ingestResults['doc-1'];
          if (result != null && !statuses.contains(result.status)) {
            statuses.add(result.status);
          }
        });

        await container
            .read(recommendationProvider.notifier)
            .ingestRecommendation(rec);

        final state = container.read(recommendationProvider);
        final result = state.ingestResults['doc-1'];

        expect(result, isNotNull);
        expect(result!.status, RecommendationIngestStatus.completed);
        expect(result.evaluation, isNotNull);
        expect(result.evaluation!.matchedCount, 1);
        expect(result.evaluation!.accuracy, 1.0);

        // Verify ingested concept IDs are populated for glow animation.
        expect(result.ingestedConceptIds, contains('ml-db'));

        // Verify transitions happened in order.
        expect(
          statuses,
          containsAllInOrder([
            RecommendationIngestStatus.ingesting,
            RecommendationIngestStatus.evaluating,
            RecommendationIngestStatus.completed,
          ]),
        );
      },
    );

    test('error sets status to error with message', () async {
      final httpClient = MockClient(
        (_) async => http.Response('Server Error', 500),
      );

      final container = createContainer(httpClient: httpClient);
      await container.read(knowledgeGraphProvider.future);

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Broken Doc',
        gap: testGap,
        score: 0.5,
        reasoning: 'Test',
      );

      await container
          .read(recommendationProvider.notifier)
          .ingestRecommendation(rec);

      final state = container.read(recommendationProvider);
      final result = state.ingestResults['doc-1'];

      expect(result, isNotNull);
      expect(result!.status, RecommendationIngestStatus.error);
      expect(result.errorMessage, isNotEmpty);
    });

    test('graph reflects new concepts after ingestion', () async {
      final httpClient = MockClient((request) async {
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'doc-1',
                'title': 'New Concepts',
                'text': '# New\nStuff here.',
              },
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final initialGraph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'A',
            description: 'Concept A',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'B',
            description: 'Concept B',
            sourceDocumentId: 'd',
          ),
        ],
      );

      when(
        () => mockExtraction.extract(
          documentTitle: any(named: 'documentTitle'),
          documentContent: any(named: 'documentContent'),
          existingConceptIds: any(named: 'existingConceptIds'),
          predictionAccuracy: any(named: 'predictionAccuracy'),
        ),
      ).thenAnswer(
        (_) async => ExtractionResult(
          concepts: [
            Concept(
              id: 'c',
              name: 'C',
              description: 'Concept C',
              sourceDocumentId: '',
            ),
          ],
          relationships: const [
            Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'c',
              label: 'enables',
              type: RelationshipType.enables,
            ),
          ],
          quizItems: const [],
        ),
      );

      final container = createContainer(
        httpClient: httpClient,
        initialGraph: initialGraph,
      );
      await container.read(knowledgeGraphProvider.future);

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'New Concepts',
        gap: testGap,
        score: 0.7,
        reasoning: 'Adds C',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'A',
            toConceptName: 'C',
            type: RelationshipType.enables,
            confidence: 0.9,
          ),
        ],
      );

      await container
          .read(recommendationProvider.notifier)
          .ingestRecommendation(rec);

      final graph = await container.read(knowledgeGraphProvider.future);
      expect(graph.concepts.map((c) => c.id), contains('c'));
      expect(graph.relationships, hasLength(1));

      final result =
          container.read(recommendationProvider).ingestResults['doc-1'];
      expect(result!.evaluation!.totalActualNew, greaterThanOrEqualTo(1));
    });
  });
}

/// In-memory graph notifier for provider tests (no Firestore dependency).
class _InMemoryGraphNotifier extends KnowledgeGraphNotifier {
  _InMemoryGraphNotifier([KnowledgeGraph? initial])
    : _graph = initial ?? KnowledgeGraph.empty;

  KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;

  @override
  Future<void> updateQuizItem(QuizItem updated) async {
    _graph = _graph.withUpdatedQuizItem(updated);
    state = AsyncData(_graph);
  }

  @override
  Future<void> ingestExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    String? collectionId,
    String? collectionName,
    String? documentText,
  }) async {
    _graph = _graph.withNewExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
      documentText: documentText,
    );
    state = AsyncData(_graph);
  }
}
