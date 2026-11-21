import 'package:drift/native.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/graph_store_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/split_concept_provider.dart';
import 'package:engram/src/storage/drift/drift_graph_repository.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  late EngramDatabase db;
  late DriftGraphRepository repo;

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGraphRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> createContainer({KnowledgeGraph? initial}) async {
    if (initial != null) {
      await repo.seedEmpty(initial);
    }

    final container = ProviderContainer(
      overrides: [graphRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SplitConceptNotifier', () {
    test('starts in idle phase', () async {
      final container = await createContainer();

      final state = container.read(splitConceptProvider);
      expect(state.phase, SplitPhase.idle);
      expect(state.parentConceptId, isNull);
      expect(state.suggestion, isNull);
    });

    test('reset returns to idle', () async {
      final container = await createContainer();

      container.read(splitConceptProvider.notifier).reset();
      expect(container.read(splitConceptProvider).phase, SplitPhase.idle);
    });
  });

  group('splitConcept on KnowledgeGraphNotifier', () {
    test('adds children, relationships, and quiz items to graph', () async {
      final initialGraph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'parent',
            name: 'Parent',
            description: 'desc',
            sourceDocumentId: 'doc1',
          ),
        ],
      );

      final container = await createContainer(initial: initialGraph);

      await container.read(knowledgeGraphProvider.future);

      await container
          .read(knowledgeGraphProvider.notifier)
          .splitConcept(
            children: [
              Concept(
                id: 'child1',
                name: 'Child 1',
                description: 'First sub-concept',
                sourceDocumentId: 'doc1',
                parentConceptId: 'parent',
              ),
              Concept(
                id: 'child2',
                name: 'Child 2',
                description: 'Second sub-concept',
                sourceDocumentId: 'doc1',
                parentConceptId: 'parent',
              ),
            ],
            childRelationships: [
              const Relationship(
                id: 'child1-part-of-parent',
                fromConceptId: 'child1',
                toConceptId: 'parent',
                label: 'is part of',
              ),
              const Relationship(
                id: 'child2-part-of-parent',
                fromConceptId: 'child2',
                toConceptId: 'parent',
                label: 'is part of',
              ),
            ],
            childQuizItems: [
              QuizItem.newCard(
                id: 'q-child1',
                conceptId: 'child1',
                question: 'What is child 1?',
                answer: 'First aspect.',
              ),
              QuizItem.newCard(
                id: 'q-child2',
                conceptId: 'child2',
                question: 'What is child 2?',
                answer: 'Second aspect.',
              ),
            ],
          );

      final graph = container.read(knowledgeGraphProvider).valueOrNull;
      expect(graph, isNotNull);
      expect(graph!.concepts.length, 3); // parent + 2 children
      expect(graph.relationships.length, 2);
      expect(graph.quizItems.length, 2);

      // Verify child concept has parent reference
      final child1 = graph.concepts.firstWhere((c) => c.id == 'child1');
      expect(child1.parentConceptId, 'parent');
      expect(child1.isSubConcept, isTrue);

      // Verify persisted to database
      final loaded = await repo.load();
      expect(loaded.concepts.length, 3);
    });
  });
}
