import 'dart:convert';
import 'dart:io';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
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
        settingsProvider
            .overrideWith(() => _FakeSettingsNotifier(tempDir.path)),
        graphRepositoryProvider.overrideWithValue(store),
      ],
    );
  }

  group('KnowledgeGraphNotifier', () {
    test('build loads empty graph when no file exists', () async {
      final container = createContainer();
      final graph =
          await container.read(knowledgeGraphProvider.future);
      expect(graph.concepts, isEmpty);
      expect(graph.quizItems, isEmpty);
    });

    test('build loads existing graph from disk', () async {
      const graph = KnowledgeGraph(
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
      final loaded =
          await container.read(knowledgeGraphProvider.future);
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

      final updated = item.withReview(
        easeFactor: 2.6,
        interval: 1,
        repetitions: 1,
        nextReview: '2025-01-02T00:00:00.000Z',
      );
      await container
          .read(knowledgeGraphProvider.notifier)
          .updateQuizItem(updated);

      final newGraph =
          await container.read(knowledgeGraphProvider.future);
      expect(newGraph.quizItems.first.repetitions, 1);

      // Verify persisted to disk
      final reloaded = await store.load();
      expect(reloaded.quizItems.first.repetitions, 1);
    });

    test('ingestExtraction adds concepts and persists', () async {
      final container = createContainer();
      await container.read(knowledgeGraphProvider.future);

      final result = ExtractionResult(
        concepts: [
          const Concept(
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

      final graph =
          await container.read(knowledgeGraphProvider.future);
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
