import 'dart:convert';
import 'dart:io';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/models/topic.dart';
import 'package:engram/src/providers/graph_store_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/storage/config.dart';
import 'package:engram/src/storage/local_graph_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late LocalGraphRepository store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('engram_provider_test_');
    store = LocalGraphRepository(dataDir: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  ProviderContainer createContainer({KnowledgeGraph? initial}) {
    if (initial != null) {
      final json = const JsonEncoder.withIndent('  ').convert(initial.toJson());
      File('${tempDir.path}/knowledge_graph.json').writeAsStringSync(json);
    }

    return ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => _FakeSettingsNotifier(tempDir.path),
        ),
        graphRepositoryProvider.overrideWithValue(store),
      ],
    );
  }

  group('KnowledgeGraphNotifier', () {
    test('build loads empty graph when no file exists', () async {
      final container = createContainer();
      final graph = await container.read(knowledgeGraphProvider.future);
      expect(graph.concepts, isEmpty);
      expect(graph.quizItems, isEmpty);
    });

    test('build loads existing graph from disk', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Concept 1',
            description: 'Desc',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      final container = createContainer(initial: graph);
      final loaded = await container.read(knowledgeGraphProvider.future);
      expect(loaded.concepts, hasLength(1));
      expect(loaded.concepts.first.id, 'c1');
    });

    test('updateQuizItem persists changes', () async {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What?',
        answer: 'That.',
      );
      final graph = KnowledgeGraph(quizItems: [item]);
      final container = createContainer(initial: graph);

      await container.read(knowledgeGraphProvider.future);

      final updated = item.withFsrsReview(
        difficulty: 4.5,
        stability: 10.0,
        fsrsState: 2,
        lapses: 0,
        interval: 10,
        nextReview: DateTime.utc(2025, 1, 11),
      );
      await container
          .read(knowledgeGraphProvider.notifier)
          .updateQuizItem(updated);

      final newGraph = await container.read(knowledgeGraphProvider.future);
      expect(newGraph.quizItems.first.fsrsState, 2);

      // Verify persisted to disk
      final reloaded = await store.load();
      expect(reloaded.quizItems.first.fsrsState, 2);
    });

    test('auto-migrates collections to topics on first load', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
          ),
          Concept(
            id: 'c2',
            name: 'Kubernetes',
            description: 'Orchestration',
            sourceDocumentId: 'doc2',
          ),
          Concept(
            id: 'c3',
            name: 'React',
            description: 'UI library',
            sourceDocumentId: 'doc3',
          ),
        ],
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Docker Guide',
            updatedAt: '2025-01-01',
            ingestedAt: DateTime.utc(2025),
            collectionId: 'col-infra',
            collectionName: 'Infrastructure',
          ),
          DocumentMetadata(
            documentId: 'doc2',
            title: 'K8s Guide',
            updatedAt: '2025-01-02',
            ingestedAt: DateTime.utc(2025, 1, 2),
            collectionId: 'col-infra',
            collectionName: 'Infrastructure',
          ),
          DocumentMetadata(
            documentId: 'doc3',
            title: 'React Guide',
            updatedAt: '2025-01-03',
            ingestedAt: DateTime.utc(2025, 1, 3),
            collectionId: 'col-frontend',
            collectionName: 'Frontend',
          ),
        ],
        // No topics — triggers auto-migration
      );

      final container = createContainer(initial: graph);
      final loaded = await container.read(knowledgeGraphProvider.future);

      // Should have 2 auto-generated topics (one per collection)
      expect(loaded.topics, hasLength(2));

      final infraTopic =
          loaded.topics.where((t) => t.name == 'Infrastructure').first;
      expect(infraTopic.id, 'auto-col-infra');
      expect(infraTopic.documentIds, containsAll(['doc1', 'doc2']));
      expect(infraTopic.description, 'Auto-migrated from collection');

      final frontendTopic =
          loaded.topics.where((t) => t.name == 'Frontend').first;
      expect(frontendTopic.id, 'auto-col-frontend');
      expect(frontendTopic.documentIds, contains('doc3'));
    });

    test('does not auto-migrate when topics already exist', () async {
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Docker Guide',
            updatedAt: '2025-01-01',
            ingestedAt: DateTime.utc(2025),
            collectionId: 'col-1',
            collectionName: 'Infra',
          ),
        ],
        topics: [
          Topic(
            id: 'existing-topic',
            name: 'Existing',
            createdAt: DateTime.utc(2025),
          ),
        ],
      );

      final container = createContainer(initial: graph);
      final loaded = await container.read(knowledgeGraphProvider.future);

      // Should keep the existing topic and NOT add auto-migrated ones
      expect(loaded.topics, hasLength(1));
      expect(loaded.topics.first.id, 'existing-topic');
    });

    test('skips metadata without collectionId during auto-migration', () async {
      final graph = KnowledgeGraph(
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'No Collection',
            updatedAt: '2025-01-01',
            ingestedAt: DateTime.utc(2025),
            // No collectionId
          ),
          DocumentMetadata(
            documentId: 'doc2',
            title: 'Has Collection',
            updatedAt: '2025-01-02',
            ingestedAt: DateTime.utc(2025, 1, 2),
            collectionId: 'col-1',
            collectionName: 'Infra',
          ),
        ],
      );

      final container = createContainer(initial: graph);
      final loaded = await container.read(knowledgeGraphProvider.future);

      // Only one topic for the metadata with a collectionId
      expect(loaded.topics, hasLength(1));
      expect(loaded.topics.first.documentIds, contains('doc2'));
      expect(loaded.topics.first.documentIds, isNot(contains('doc1')));
    });

    test('ingestExtraction adds concepts and persists', () async {
      final container = createContainer();
      await container.read(knowledgeGraphProvider.future);

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: '',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c1',
            toConceptId: 'c1',
            label: 'related to',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'What is Docker?',
            answer: 'A container runtime',
          ),
        ],
      );

      await container
          .read(knowledgeGraphProvider.notifier)
          .ingestExtraction(
            result,
            documentId: 'doc1',
            documentTitle: 'Docker Guide',
            updatedAt: '2025-01-01T00:00:00.000Z',
          );

      final graph = await container.read(knowledgeGraphProvider.future);
      expect(graph.concepts, hasLength(1));
      expect(graph.documentMetadata, hasLength(1));

      // Verify persisted
      final reloaded = await store.load();
      expect(reloaded.concepts, hasLength(1));
    });
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._dataDir);
  final String _dataDir;

  @override
  EngramConfig build() => EngramConfig(dataDir: _dataDir);
}
