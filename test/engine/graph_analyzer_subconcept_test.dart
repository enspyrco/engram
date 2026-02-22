import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

Concept _concept(String id, {String? parentConceptId}) => Concept(
  id: id,
  name: id,
  description: 'desc',
  sourceDocumentId: 'doc1',
  parentConceptId: parentConceptId,
);

/// FSRS quiz item. [fsrsState] >= 2 means graduated.
QuizItem _quiz(String id, String conceptId, {int fsrsState = 1}) => QuizItem(
  id: id,
  conceptId: conceptId,
  question: 'Q?',
  answer: 'A.',
  interval: 1,
  nextReview: DateTime.utc(2025, 6, 15),
  lastReview: null,
  difficulty: 5.0,
  stability: 3.26,
  fsrsState: fsrsState,
  lapses: 0,
);

void main() {
  group('sub-concept parent-child relationships', () {
    test('childrenOf returns child concept IDs', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
          _concept('child2', parentConceptId: 'parent'),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(analyzer.childrenOf('parent'), {'child1', 'child2'});
      expect(analyzer.childrenOf('child1'), isEmpty);
    });

    test('hasChildren is true for split concepts', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(analyzer.hasChildren('parent'), isTrue);
      expect(analyzer.hasChildren('child1'), isFalse);
    });

    test('hasChildren is false for concepts without children', () {
      final graph = KnowledgeGraph(concepts: [_concept('solo')]);
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.hasChildren('solo'), isFalse);
    });
  });

  group('parent mastery depends on children', () {
    test('parent is mastered only when all children are mastered', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
          _concept('child2', parentConceptId: 'parent'),
        ],
        quizItems: [
          _quiz('q1', 'child1', fsrsState: 2),
          _quiz('q2', 'child2', fsrsState: 2),
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptGraduated('parent'), isTrue);
    });

    test('parent is not mastered when any child is not mastered', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
          _concept('child2', parentConceptId: 'parent'),
        ],
        quizItems: [
          _quiz('q1', 'child1', fsrsState: 2),
          _quiz('q2', 'child2', fsrsState: 1), // not mastered
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptGraduated('parent'), isFalse);
    });

    test('parent with no quiz items but children delegates to children', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
        ],
        quizItems: [_quiz('q1', 'child1', fsrsState: 1)],
      );
      final analyzer = GraphAnalyzer(graph);
      // Parent has no own quiz items, but has children → delegates
      expect(analyzer.isConceptGraduated('parent'), isFalse);
    });
  });

  group('child unlock inherits parent status', () {
    test('children inherit unlock from parent prerequisites', () {
      // prereq → parent → child1, child2
      final graph = KnowledgeGraph(
        concepts: [
          _concept('prereq'),
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
          _concept('child2', parentConceptId: 'parent'),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'parent',
            toConceptId: 'prereq',
            label: 'depends on',
          ),
        ],
        quizItems: [
          _quiz('q1', 'prereq', fsrsState: 1), // not mastered
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      // Parent locked → children also locked
      expect(analyzer.isConceptUnlocked('parent'), isFalse);
      expect(analyzer.isConceptUnlocked('child1'), isFalse);
      expect(analyzer.isConceptUnlocked('child2'), isFalse);
    });

    test('children unlocked when parent prerequisites mastered', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('prereq'),
          _concept('parent'),
          _concept('child1', parentConceptId: 'parent'),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'parent',
            toConceptId: 'prereq',
            label: 'depends on',
          ),
        ],
        quizItems: [
          _quiz('q1', 'prereq', fsrsState: 2), // mastered
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(analyzer.isConceptUnlocked('parent'), isTrue);
      expect(analyzer.isConceptUnlocked('child1'), isTrue);
    });
  });

  group('cycle guard in mastery check', () {
    test('does not infinite loop on malformed parent-child cycles', () {
      // Pathological: child claims parent is its parent, parent claims child
      final graph = KnowledgeGraph(
        concepts: [
          _concept('a', parentConceptId: 'b'),
          _concept('b', parentConceptId: 'a'),
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      // Should not hang — cycle guard returns true
      expect(analyzer.isConceptGraduated('a'), isTrue);
    });
  });
}
