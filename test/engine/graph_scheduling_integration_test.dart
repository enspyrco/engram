import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/engine/scheduler.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

/// Integration test: build a graph with a dependency chain
/// compose → containers → images, then verify scheduling respects it.

Concept _concept(String id) => Concept(
  id: id,
  name: id,
  description: 'desc',
  sourceDocumentId: 'doc1',
  tags: const [],
);

Relationship _dep(String from, String to) => Relationship(
  id: '$from-$to',
  fromConceptId: from,
  toConceptId: to,
  label: 'depends on',
);

QuizItem _quiz(
  String id,
  String conceptId, {
  int repetitions = 0,
  DateTime? nextReview,
}) => QuizItem(
  id: id,
  conceptId: conceptId,
  question: 'Q about $conceptId?',
  answer: 'A about $conceptId.',
  easeFactor: 2.5,
  interval: 1,
  repetitions: repetitions,
  nextReview: nextReview ?? DateTime.utc(2025, 6, 1),
  lastReview: null,
);

void main() {
  final now = DateTime.utc(2025, 6, 15, 12, 0);

  group('Graph scheduling integration', () {
    // Dependency chain: compose → containers → images
    // All items are due.
    KnowledgeGraph buildGraph({
      int imagesReps = 0,
      int containersReps = 0,
      int composeReps = 0,
    }) {
      return KnowledgeGraph(
        concepts: [
          _concept('compose'),
          _concept('containers'),
          _concept('images'),
        ],
        relationships: [
          _dep('compose', 'containers'),
          _dep('containers', 'images'),
        ],
        quizItems: [
          _quiz('q-images', 'images', repetitions: imagesReps),
          _quiz('q-containers', 'containers', repetitions: containersReps),
          _quiz('q-compose', 'compose', repetitions: composeReps),
        ],
      );
    }

    test('initially only foundational items are scheduled', () {
      final graph = buildGraph();
      final due = scheduleDueItems(graph, now: now);

      // Only images (the foundational concept) should appear
      expect(due.length, 1);
      expect(due.first.id, 'q-images');
    });

    test('mastering images unlocks containers', () {
      final graph = buildGraph(imagesReps: 1);
      final due = scheduleDueItems(graph, now: now);

      expect(due.map((i) => i.id), containsAll(['q-images', 'q-containers']));
      expect(due.length, 2);
    });

    test('mastering images + containers unlocks compose', () {
      final graph = buildGraph(imagesReps: 1, containersReps: 1);
      final due = scheduleDueItems(graph, now: now);

      expect(due.length, 3);
      expect(
        due.map((i) => i.id),
        containsAll(['q-images', 'q-containers', 'q-compose']),
      );
    });

    test('foundational items sort before non-foundational', () {
      // images mastered, both containers and images are due
      // images is foundational → should come first
      final graph = buildGraph(imagesReps: 1);
      final due = scheduleDueItems(graph, now: now);

      expect(due.first.id, 'q-images');
    });

    test('GraphAnalyzer tracks locked/unlocked correctly through chain', () {
      final graph = buildGraph();
      final analyzer = GraphAnalyzer(graph);

      expect(analyzer.foundationalConcepts, ['images']);
      expect(analyzer.unlockedConcepts, ['images']);
      expect(
        analyzer.lockedConcepts,
        unorderedEquals(['compose', 'containers']),
      );
      expect(analyzer.hasCycles(), isFalse);

      // After mastering images
      final graph2 = buildGraph(imagesReps: 1);
      final analyzer2 = GraphAnalyzer(graph2);
      expect(
        analyzer2.unlockedConcepts,
        unorderedEquals(['images', 'containers']),
      );
      expect(analyzer2.lockedConcepts, ['compose']);

      // After mastering images + containers
      final graph3 = buildGraph(imagesReps: 1, containersReps: 1);
      final analyzer3 = GraphAnalyzer(graph3);
      expect(
        analyzer3.unlockedConcepts,
        unorderedEquals(['images', 'containers', 'compose']),
      );
      expect(analyzer3.lockedConcepts, isEmpty);
    });

    test('topological sort respects dependency order', () {
      final graph = buildGraph();
      final sorted = GraphAnalyzer(graph).topologicalSort();

      expect(sorted, isNotNull);
      expect(sorted!.indexOf('images'), lessThan(sorted.indexOf('containers')));
      expect(sorted.indexOf('containers'), lessThan(sorted.indexOf('compose')));
    });

    test('non-dependency edges do not affect scheduling', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b'), _concept('c')],
        relationships: [
          // a depends on b (dependency)
          _dep('a', 'b'),
          // c "is a type of" a (not dependency)
          const Relationship(
            id: 'c-a',
            fromConceptId: 'c',
            toConceptId: 'a',
            label: 'is a type of',
          ),
        ],
        quizItems: [_quiz('q-a', 'a'), _quiz('q-b', 'b'), _quiz('q-c', 'c')],
      );

      final due = scheduleDueItems(graph, now: now);

      // b and c should be scheduled (b is foundational, c has no dependency edges)
      // a is locked (depends on b which is unmastered)
      expect(due.map((i) => i.id), unorderedEquals(['q-b', 'q-c']));
    });

    test('cycle detection works in integration', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_dep('a', 'b'), _dep('b', 'a')],
        quizItems: [_quiz('q-a', 'a'), _quiz('q-b', 'b')],
      );

      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.hasCycles(), isTrue);

      // With a cycle, neither concept's prerequisites are mastered
      // (a needs b, b needs a), so both are locked
      final due = scheduleDueItems(graph, now: now);
      expect(due, isEmpty);
    });
  });
}
