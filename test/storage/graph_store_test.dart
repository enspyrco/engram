import 'dart:io';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/storage/local_graph_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late LocalGraphRepository store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('engram_test_');
    store = LocalGraphRepository(dataDir: tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('LocalGraphRepository', () {
    test('load returns empty graph when file does not exist', () async {
      final graph = await store.load();
      expect(graph.concepts, isEmpty);
      expect(graph.quizItems, isEmpty);
    });

    test('save and load round-trips', () async {
      final graph = KnowledgeGraph(
        concepts: const [
          Concept(
            id: 'c1',
            name: 'Concept 1',
            description: 'Desc',
            sourceDocumentId: 'doc-1',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      await store.save(graph);
      final loaded = await store.load();

      expect(loaded.concepts.length, 1);
      expect(loaded.concepts.first.id, 'c1');
      expect(loaded.quizItems.length, 1);
      expect(loaded.quizItems.first.id, 'q1');
    });

    test('save creates data directory if it does not exist', () async {
      final nestedDir = '${tmpDir.path}/nested/deep';
      final nestedStore = LocalGraphRepository(dataDir: nestedDir);

      await nestedStore.save(KnowledgeGraph.empty);

      expect(Directory(nestedDir).existsSync(), isTrue);
    });

    test('save is atomic (writes to temp then renames)', () async {
      // Save once
      const graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C1',
            description: 'Desc',
            sourceDocumentId: 'doc-1',
          ),
        ],
      );

      await store.save(graph);

      // The temp file should not remain
      final tmpFile = File('${tmpDir.path}/knowledge_graph.json.tmp');
      expect(tmpFile.existsSync(), isFalse);

      // The real file should exist
      final realFile = File('${tmpDir.path}/knowledge_graph.json');
      expect(realFile.existsSync(), isTrue);
    });

    test('watch emits loaded graph', () async {
      const graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C1',
            description: 'Desc',
            sourceDocumentId: 'doc-1',
          ),
        ],
      );
      await store.save(graph);

      final emitted = await store.watch().first;
      expect(emitted.concepts, hasLength(1));
      expect(emitted.concepts.first.id, 'c1');
    });
  });
}
