import 'dart:convert';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/ingest_state.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/providers/ingest_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
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
  group('IngestNotifier', () {
    late MockClient mockHttpClient;
    late MockExtractionService mockExtraction;
    late SharedPreferences prefs;
    late SettingsRepository settingsRepo;

    setUp(() async {
      mockExtraction = MockExtractionService();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      settingsRepo = SettingsRepository(prefs);
    });

    ProviderContainer createContainer({
      required http.Client httpClient,
    }) {
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          knowledgeGraphProvider
              .overrideWith(() => _InMemoryGraphNotifier()),
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

    test('initial state is idle', () {
      mockHttpClient = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(httpClient: mockHttpClient);
      final state = container.read(ingestProvider);
      expect(state.phase, IngestPhase.idle);
    });

    test('loadCollections fetches and transitions to ready', () async {
      mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/collections.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'col1', 'name': 'Engineering'},
                {'id': 'col2', 'name': 'Design'},
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: mockHttpClient);
      await container.read(ingestProvider.notifier).loadCollections();

      final state = container.read(ingestProvider);
      expect(state.phase, IngestPhase.ready);
      expect(state.collections, hasLength(2));
    });

    test('loadCollections handles errors', () async {
      mockHttpClient = MockClient((_) async => http.Response('error', 500));

      final container = createContainer(httpClient: mockHttpClient);
      await container.read(ingestProvider.notifier).loadCollections();

      final state = container.read(ingestProvider);
      expect(state.phase, IngestPhase.error);
      expect(state.errorMessage, contains('Failed to load collections'));
    });

    test('selectCollection updates selected', () {
      mockHttpClient = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(httpClient: mockHttpClient);

      final collection = {'id': 'col1', 'name': 'Engineering'};
      container.read(ingestProvider.notifier).selectCollection(collection);

      final state = container.read(ingestProvider);
      expect(state.selectedCollection?['id'], 'col1');
    });

    test('startIngestion processes documents', () async {
      mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/documents.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'doc1',
                  'title': 'Docker Guide',
                  'updatedAt': '2025-01-01T00:00:00.000Z',
                },
              ],
              'pagination': {'total': 1},
            }),
            200,
          );
        }
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'doc1',
                'title': 'Docker Guide',
                'text': '# Docker\nContainers are cool.',
              },
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      when(() => mockExtraction.extract(
            documentTitle: any(named: 'documentTitle'),
            documentContent: any(named: 'documentContent'),
            existingConceptIds: any(named: 'existingConceptIds'),
          )).thenAnswer((_) async => ExtractionResult(
            concepts: [
              Concept(
                id: 'docker',
                name: 'Docker',
                description: 'Container runtime',
                sourceDocumentId: '',
              ),
            ],
            relationships: const [],
            quizItems: [
              QuizItem.newCard(
                id: 'q1',
                conceptId: 'docker',
                question: 'What is Docker?',
                answer: 'A container runtime',
              ),
            ],
          ));

      final container = createContainer(httpClient: mockHttpClient);
      // Wait for graph to load
      await container.read(knowledgeGraphProvider.future);

      // Select a collection
      container.read(ingestProvider.notifier).selectCollection(
        {'id': 'col1', 'name': 'Engineering'},
      );

      await container.read(ingestProvider.notifier).startIngestion();

      final state = container.read(ingestProvider);
      expect(state.phase, IngestPhase.done);
      expect(state.extractedCount, 1);
      expect(state.skippedCount, 0);

      // Verify graph updated
      final graph = await container.read(knowledgeGraphProvider.future);
      expect(graph.concepts, hasLength(1));
      expect(graph.concepts.first.id, 'docker');
    });

    test('reset returns to idle', () {
      mockHttpClient = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(httpClient: mockHttpClient);

      container.read(ingestProvider.notifier).selectCollection(
        {'id': 'col1', 'name': 'Test'},
      );
      container.read(ingestProvider.notifier).reset();

      final state = container.read(ingestProvider);
      expect(state.phase, IngestPhase.idle);
      expect(state.selectedCollection, isNull);
    });
  });
}

class _InMemoryGraphNotifier extends KnowledgeGraphNotifier {
  KnowledgeGraph _graph = KnowledgeGraph.empty;

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
  }) async {
    _graph = _graph.withNewExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
    );
    state = AsyncData(_graph);
  }

  @override
  Future<void> staggeredIngestExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    String? collectionId,
    String? collectionName,
    Duration delay = const Duration(milliseconds: 250),
  }) async {
    // Skip staggering in tests — just merge immediately.
    await ingestExtraction(
      result,
      documentId: documentId,
      documentTitle: documentTitle,
      updatedAt: updatedAt,
      collectionId: collectionId,
      collectionName: collectionName,
    );
  }
}
