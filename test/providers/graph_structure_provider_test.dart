import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/graph_structure_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('graphStructureProvider', () {
    test('returns non-null when graph has concepts', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Concept 1',
            description: 'Desc',
            sourceDocumentId: 'doc1',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c1',
            toConceptId: 'c1',
            label: 'self',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(graph),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the async notifier to resolve
      await container.read(knowledgeGraphProvider.future);

      final structure = container.read(graphStructureProvider);
      expect(structure, isNotNull);
      expect(structure!.concepts, hasLength(1));
      expect(structure.relationships, hasLength(1));
    });

    test('returns null when graph has no concepts', () async {
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(KnowledgeGraph()),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the async notifier to resolve
      await container.read(knowledgeGraphProvider.future);

      final structure = container.read(graphStructureProvider);
      expect(structure, isNull);
    });

    test('structural identity preserved after quiz item update', () async {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Concept 1',
            description: 'Desc',
            sourceDocumentId: 'doc1',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c1',
            toConceptId: 'c1',
            label: 'self',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'What?',
            answer: 'That.',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(graph),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the async notifier to resolve
      await container.read(knowledgeGraphProvider.future);

      // Read initial structure
      final before = container.read(graphStructureProvider);
      expect(before, isNotNull);

      // Simulate a quiz item update via setGraph + withUpdatedQuizItem
      // (same path as updateQuizItem but without needing repository I/O)
      final fullBefore = container.read(knowledgeGraphProvider).valueOrNull!;
      final updated = fullBefore.quizItems.first.withFsrsReview(
        difficulty: 4.5,
        stability: 10.0,
        fsrsState: 2,
        lapses: 0,
        interval: 10,
        nextReview: DateTime.utc(2025, 1, 11),
      );
      final newGraph = fullBefore.withUpdatedQuizItem(updated);
      container.read(knowledgeGraphProvider.notifier).setGraph(newGraph);

      // Verify the full graph changed (quiz items updated)
      final fullGraph = container.read(knowledgeGraphProvider).valueOrNull;
      expect(fullGraph, isNotNull);
      expect(fullGraph!.quizItems.first.fsrsState, 2);

      // Verify structural provider still returns data with same concepts
      final after = container.read(graphStructureProvider);
      expect(after, isNotNull);
      expect(after!.concepts.length, before!.concepts.length);
      expect(after.relationships.length, before.relationships.length);
      expect(after.concepts.first.id, before.concepts.first.id);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._initial);

  final KnowledgeGraph _initial;

  @override
  Future<KnowledgeGraph> build() async => _initial;
}
