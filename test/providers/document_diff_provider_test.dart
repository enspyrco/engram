import 'dart:convert';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/providers/document_diff_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/service_providers.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/services/outline_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._graph);
  final KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;
}

void main() {
  group('DocumentDiffNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer({
      required http.Client httpClient,
      required KnowledgeGraph graph,
    }) {
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          outlineClientProvider.overrideWithValue(
            OutlineClient(
              apiUrl: 'https://wiki.test.com',
              apiKey: 'test-key',
              httpClient: httpClient,
            ),
          ),
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(graph),
          ),
        ],
      );
    }

    KnowledgeGraph graphWithMetadata({
      required String documentId,
      required DateTime ingestedAt,
      String? ingestedText,
    }) {
      return KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Test Concept',
            description: 'desc',
            sourceDocumentId: documentId,
          ),
        ],
        relationships: const [],
        documentMetadata: [
          DocumentMetadata(
            documentId: documentId,
            title: 'Test Doc',
            updatedAt: '2026-02-17T10:00:00Z',
            ingestedAt: ingestedAt,
            ingestedText: ingestedText,
          ),
        ],
      );
    }

    test('initial state is idle', () {
      final mockClient = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(
        httpClient: mockClient,
        graph: KnowledgeGraph.empty,
      );

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffIdle>());
    });

    test(
      'fetchDiff loads current text and compares with ingestedText',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/documents.info') {
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'doc-1',
                  'title': 'Test Doc',
                  'text': '# Updated\nNew paragraph.',
                },
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });

        final graph = graphWithMetadata(
          documentId: 'doc-1',
          ingestedAt: DateTime.utc(2026, 2, 18),
          ingestedText: '# Original',
        );

        final container = createContainer(httpClient: mockClient, graph: graph);

        // Wait for graph to load.
        await container.read(knowledgeGraphProvider.future);

        final notifier = container.read(documentDiffProvider.notifier);
        await notifier.fetchDiff(documentId: 'doc-1');

        final state = container.read(documentDiffProvider);
        expect(state, isA<DocumentDiffLoaded>());

        final loaded = state as DocumentDiffLoaded;
        expect(loaded.oldText, '# Original');
        expect(loaded.newText, '# Updated\nNew paragraph.');
        expect(loaded.ingestedAt, DateTime.utc(2026, 2, 18));
      },
    );

    test('returns error when no ingestedText stored', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 200));

      final graph = graphWithMetadata(
        documentId: 'doc-1',
        ingestedAt: DateTime.utc(2026, 2, 18),
        ingestedText: null, // no stored text
      );

      final container = createContainer(httpClient: mockClient, graph: graph);
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(documentDiffProvider.notifier);
      await notifier.fetchDiff(documentId: 'doc-1');

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffError>());
      expect(
        (state as DocumentDiffError).message,
        contains('No previous version'),
      );
    });

    test('returns error when document metadata not found', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 200));

      final container = createContainer(
        httpClient: mockClient,
        graph: KnowledgeGraph.empty,
      );
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(documentDiffProvider.notifier);
      await notifier.fetchDiff(documentId: 'nonexistent');

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffError>());
      expect(
        (state as DocumentDiffError).message,
        contains('metadata not found'),
      );
    });

    test('transitions to error on API failure', () async {
      final mockClient = MockClient((_) async {
        return http.Response('Server Error', 500);
      });

      final graph = graphWithMetadata(
        documentId: 'doc-1',
        ingestedAt: DateTime.utc(2026, 2, 18),
        ingestedText: '# Old text',
      );

      final container = createContainer(httpClient: mockClient, graph: graph);
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(documentDiffProvider.notifier);
      await notifier.fetchDiff(documentId: 'doc-1');

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffError>());
      expect((state as DocumentDiffError).message, contains('failed'));
    });

    test('reset returns to idle', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {'id': 'doc-1', 'text': '# Current'},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final graph = graphWithMetadata(
        documentId: 'doc-1',
        ingestedAt: DateTime.utc(2026, 2, 18),
        ingestedText: '# Old',
      );

      final container = createContainer(httpClient: mockClient, graph: graph);
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(documentDiffProvider.notifier);
      await notifier.fetchDiff(documentId: 'doc-1');
      expect(container.read(documentDiffProvider), isA<DocumentDiffLoaded>());

      notifier.reset();
      expect(container.read(documentDiffProvider), isA<DocumentDiffIdle>());
    });
  });
}
