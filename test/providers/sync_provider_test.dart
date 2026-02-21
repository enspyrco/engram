import 'dart:convert';

import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/sync_status.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/service_providers.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/providers/sync_provider.dart';
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

/// Returns an HTTP response listing the given collections.
String _collectionsJson(List<Map<String, String>> collections) {
  return jsonEncode({
    'data': collections,
    'pagination': {'total': collections.length},
  });
}

void main() {
  group('SyncNotifier', () {
    late MockExtractionService mockExtraction;
    late SharedPreferences prefs;
    late SettingsRepository settingsRepo;

    setUp(() async {
      mockExtraction = MockExtractionService();
      SharedPreferences.setMockInitialValues({
        'outline_api_url': 'https://wiki.test.com',
        'outline_api_key': 'test-key',
        'anthropic_api_key': 'sk-ant-test',
        'ingested_collection_ids': ['col1'],
      });
      prefs = await SharedPreferences.getInstance();
      settingsRepo = SettingsRepository(prefs);
    });

    ProviderContainer createContainer({
      required http.Client httpClient,
      KnowledgeGraph? graph,
    }) {
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dataDirProvider.overrideWithValue('/tmp/engram_test'),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(graph ?? KnowledgeGraph.empty),
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

    test('initial state is idle', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(httpClient: client);
      final state = container.read(syncProvider);
      expect(state.phase, SyncPhase.idle);
    });

    test('checkForUpdates finds stale documents', () async {
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Docker Guide',
            updatedAt: '2025-01-01T00:00:00.000Z',
            ingestedAt: DateTime.utc(2025, 1, 1, 12),
          ),
        ],
      );

      final client = MockClient((request) async {
        if (request.url.path == '/api/collections.list') {
          return http.Response(
            _collectionsJson([
              {'id': 'col1', 'name': 'DevOps'},
            ]),
            200,
          );
        }
        if (request.url.path == '/api/documents.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'doc1',
                  'title': 'Docker Guide',
                  'updatedAt': '2025-02-01T00:00:00.000Z', // newer
                },
              ],
              'pagination': {'total': 1},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: client, graph: graph);
      await container.read(knowledgeGraphProvider.future);
      await container.read(syncProvider.notifier).checkForUpdates();

      final state = container.read(syncProvider);
      expect(state.phase, SyncPhase.updatesAvailable);
      expect(state.staleDocumentCount, 1);
      expect(state.staleCollectionIds, ['col1']);
    });

    test('checkForUpdates reports up-to-date when no changes', () async {
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Docker Guide',
            updatedAt: '2025-01-01T00:00:00.000Z',
            ingestedAt: DateTime.utc(2025, 1, 1, 12),
          ),
        ],
      );

      final client = MockClient((request) async {
        if (request.url.path == '/api/collections.list') {
          return http.Response(
            _collectionsJson([
              {'id': 'col1', 'name': 'DevOps'},
            ]),
            200,
          );
        }
        if (request.url.path == '/api/documents.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'doc1',
                  'title': 'Docker Guide',
                  'updatedAt': '2025-01-01T00:00:00.000Z', // same
                },
              ],
              'pagination': {'total': 1},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: client, graph: graph);
      await container.read(knowledgeGraphProvider.future);
      await container.read(syncProvider.notifier).checkForUpdates();

      final state = container.read(syncProvider);
      expect(state.phase, SyncPhase.upToDate);
    });

    test(
      'checkForUpdates detects new documents in existing collection',
      () async {
        // Graph has doc1, but Outline returns doc1 + doc2 (new)
        final graph = KnowledgeGraph(
          documentMetadata: [
            DocumentMetadata(
              documentId: 'doc1',
              title: 'Docker Guide',
              updatedAt: '2025-01-01T00:00:00.000Z',
              ingestedAt: DateTime.utc(2025, 1, 1, 12),
            ),
          ],
        );

        final client = MockClient((request) async {
          if (request.url.path == '/api/collections.list') {
            return http.Response(
              _collectionsJson([
                {'id': 'col1', 'name': 'DevOps'},
              ]),
              200,
            );
          }
          if (request.url.path == '/api/documents.list') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'doc1',
                    'title': 'Docker Guide',
                    'updatedAt': '2025-01-01T00:00:00.000Z', // unchanged
                  },
                  {
                    'id': 'doc2',
                    'title': 'Kubernetes Guide',
                    'updatedAt': '2025-02-01T00:00:00.000Z', // new doc
                  },
                ],
                'pagination': {'total': 2},
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });

        final container = createContainer(httpClient: client, graph: graph);
        await container.read(knowledgeGraphProvider.future);
        await container.read(syncProvider.notifier).checkForUpdates();

        final state = container.read(syncProvider);
        expect(state.phase, SyncPhase.updatesAvailable);
        expect(state.staleDocumentCount, 1); // doc2 is new
      },
    );

    test(
      'checkForUpdates reports up-to-date when no collections exist',
      () async {
        // Override with empty ingested collection list
        SharedPreferences.setMockInitialValues({
          'outline_api_url': 'https://wiki.test.com',
          'outline_api_key': 'test-key',
          'anthropic_api_key': 'sk-ant-test',
        });
        prefs = await SharedPreferences.getInstance();
        settingsRepo = SettingsRepository(prefs);

        final graph = KnowledgeGraph(
          documentMetadata: [
            DocumentMetadata(
              documentId: 'doc1',
              title: 'Docker Guide',
              updatedAt: '2025-01-01T00:00:00.000Z',
              ingestedAt: DateTime.utc(2025, 1, 1, 12),
            ),
          ],
        );

        // Outline also has no collections
        final client = MockClient((request) async {
          if (request.url.path == '/api/collections.list') {
            return http.Response(_collectionsJson([]), 200);
          }
          return http.Response('{}', 200);
        });
        final container = createContainer(httpClient: client, graph: graph);
        await container.read(knowledgeGraphProvider.future);
        await container.read(syncProvider.notifier).checkForUpdates();

        final state = container.read(syncProvider);
        expect(state.phase, SyncPhase.upToDate);
      },
    );

    test('checkForUpdates discovers new collections in Outline', () async {
      // col1 is ingested, but Outline now has col1 + col2
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Docker Guide',
            updatedAt: '2025-01-01T00:00:00.000Z',
            ingestedAt: DateTime.utc(2025, 1, 1, 12),
          ),
        ],
      );

      final client = MockClient((request) async {
        if (request.url.path == '/api/collections.list') {
          return http.Response(
            _collectionsJson([
              {'id': 'col1', 'name': 'DevOps'},
              {'id': 'col2', 'name': 'Kubernetes'},
            ]),
            200,
          );
        }
        if (request.url.path == '/api/documents.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'doc1',
                  'title': 'Docker Guide',
                  'updatedAt': '2025-01-01T00:00:00.000Z', // unchanged
                },
              ],
              'pagination': {'total': 1},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: client, graph: graph);
      await container.read(knowledgeGraphProvider.future);
      await container.read(syncProvider.notifier).checkForUpdates();

      final state = container.read(syncProvider);
      expect(state.phase, SyncPhase.updatesAvailable);
      expect(state.staleDocumentCount, 0); // no stale docs
      expect(state.newCollections, hasLength(1));
      expect(state.newCollections.first['name'], 'Kubernetes');
    });

    test(
      'dismissNewCollections clears banner and returns to upToDate',
      () async {
        final graph = KnowledgeGraph(
          documentMetadata: [
            DocumentMetadata(
              documentId: 'doc1',
              title: 'Docker Guide',
              updatedAt: '2025-01-01T00:00:00.000Z',
              ingestedAt: DateTime.utc(2025, 1, 1, 12),
            ),
          ],
        );

        final client = MockClient((request) async {
          if (request.url.path == '/api/collections.list') {
            return http.Response(
              _collectionsJson([
                {'id': 'col1', 'name': 'DevOps'},
                {'id': 'col2', 'name': 'Kubernetes'},
              ]),
              200,
            );
          }
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
          return http.Response('{}', 200);
        });

        final container = createContainer(httpClient: client, graph: graph);
        await container.read(knowledgeGraphProvider.future);
        await container.read(syncProvider.notifier).checkForUpdates();

        // Verify new collections detected
        expect(container.read(syncProvider).newCollections, hasLength(1));

        // Dismiss
        container.read(syncProvider.notifier).dismissNewCollections();

        final state = container.read(syncProvider);
        expect(state.newCollections, isEmpty);
        expect(state.phase, SyncPhase.upToDate);
      },
    );

    test('checkForUpdates handles API errors gracefully', () async {
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Docker Guide',
            updatedAt: '2025-01-01T00:00:00.000Z',
            ingestedAt: DateTime.utc(2025, 1, 1, 12),
          ),
        ],
      );

      final client = MockClient((_) async => http.Response('error', 500));
      final container = createContainer(httpClient: client, graph: graph);
      await container.read(knowledgeGraphProvider.future);
      await container.read(syncProvider.notifier).checkForUpdates();

      final state = container.read(syncProvider);
      expect(state.phase, SyncPhase.error);
      expect(state.errorMessage, contains('Sync check failed'));
    });

    test('reset returns to idle', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(httpClient: client);

      container.read(syncProvider.notifier).reset();
      expect(container.read(syncProvider).phase, SyncPhase.idle);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._graph);
  KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;

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

  @override
  Future<void> staggeredIngestExtraction(
    ExtractionResult result, {
    required String documentId,
    required String documentTitle,
    required String updatedAt,
    String? collectionId,
    String? collectionName,
    String? documentText,
    Duration delay = const Duration(milliseconds: 250),
    int batchSize = 3,
  }) async {
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
