import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

Concept _concept(String id) => Concept(
  id: id,
  name: id,
  description: 'desc',
  sourceDocumentId: 'doc1',
  tags: const [],
);

Relationship _rel(
  String from,
  String to, {
  String label = 'depends on',
  RelationshipType? type,
}) => Relationship(
  id: '$from-$to',
  fromConceptId: from,
  toConceptId: to,
  label: label,
  type: type,
);

QuizItem _quiz(String id, String conceptId, {int repetitions = 0}) => QuizItem(
  id: id,
  conceptId: conceptId,
  question: 'Q?',
  answer: 'A.',
  easeFactor: 2.5,
  interval: 1,
  repetitions: repetitions,
  nextReview: DateTime.utc(2025, 6, 15),
  lastReview: null,
);

void main() {
  group('isDependencyEdge', () {
    test('recognises "depends on"', () {
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'depends on')),
        isTrue,
      );
    });

    test('recognises "requires"', () {
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'requires')),
        isTrue,
      );
    });

    test('recognises "prerequisite" (substring)', () {
      expect(
        GraphAnalyzer.isDependencyEdge(
          _rel('a', 'b', label: 'is a prerequisite for'),
        ),
        isTrue,
      );
    });

    test('recognises "builds on"', () {
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'builds on')),
        isTrue,
      );
    });

    test('recognises "assumes"', () {
      expect(
        GraphAnalyzer.isDependencyEdge(
          _rel('a', 'b', label: 'assumes knowledge of'),
        ),
        isTrue,
      );
    });

    test('case insensitive', () {
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'DEPENDS ON')),
        isTrue,
      );
    });

    test('rejects non-dependency labels', () {
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'is a type of')),
        isFalse,
      );
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'enables')),
        isFalse,
      );
      expect(
        GraphAnalyzer.isDependencyEdge(_rel('a', 'b', label: 'related to')),
        isFalse,
      );
    });

    test('uses explicit type over label inference', () {
      // Label says "related to" but type is prerequisite — should be dependency
      expect(
        GraphAnalyzer.isDependencyEdge(
          _rel(
            'a',
            'b',
            label: 'related to',
            type: RelationshipType.prerequisite,
          ),
        ),
        isTrue,
      );
      // Label says "depends on" but type is relatedTo — should NOT be dependency
      expect(
        GraphAnalyzer.isDependencyEdge(
          _rel('a', 'b', label: 'depends on', type: RelationshipType.relatedTo),
        ),
        isFalse,
      );
    });

    test('works with all non-prerequisite types', () {
      for (final type in RelationshipType.values) {
        if (type == RelationshipType.prerequisite) continue;
        expect(
          GraphAnalyzer.isDependencyEdge(
            _rel('a', 'b', label: 'x', type: type),
          ),
          isFalse,
          reason: '$type should not be a dependency',
        );
      }
    });
  });

  group('prerequisitesOf / dependentsOf', () {
    // compose --depends on--> containers --depends on--> images
    final graph = KnowledgeGraph(
      concepts: [
        _concept('compose'),
        _concept('containers'),
        _concept('images'),
      ],
      relationships: [
        _rel('compose', 'containers'),
        _rel('containers', 'images'),
      ],
    );
    final analyzer = GraphAnalyzer(graph);

    test('prerequisitesOf returns direct prerequisites', () {
      expect(analyzer.prerequisitesOf('compose'), {'containers'});
      expect(analyzer.prerequisitesOf('containers'), {'images'});
      expect(analyzer.prerequisitesOf('images'), isEmpty);
    });

    test('dependentsOf returns direct dependents', () {
      expect(analyzer.dependentsOf('images'), {'containers'});
      expect(analyzer.dependentsOf('containers'), {'compose'});
      expect(analyzer.dependentsOf('compose'), isEmpty);
    });

    test('returns empty for unknown concept', () {
      expect(analyzer.prerequisitesOf('nonexistent'), isEmpty);
      expect(analyzer.dependentsOf('nonexistent'), isEmpty);
    });
  });

  group('non-dependency edges ignored', () {
    final graph = KnowledgeGraph(
      concepts: [_concept('a'), _concept('b')],
      relationships: [_rel('a', 'b', label: 'is a type of')],
    );
    final analyzer = GraphAnalyzer(graph);

    test('prerequisitesOf ignores non-dependency relationships', () {
      expect(analyzer.prerequisitesOf('a'), isEmpty);
      expect(analyzer.prerequisitesOf('b'), isEmpty);
    });

    test('dependentsOf ignores non-dependency relationships', () {
      expect(analyzer.dependentsOf('a'), isEmpty);
      expect(analyzer.dependentsOf('b'), isEmpty);
    });
  });

  group('isConceptMastered', () {
    test('concept with no quiz items is mastered', () {
      final graph = KnowledgeGraph(concepts: [_concept('a')]);
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptMastered('a'), isTrue);
    });

    test('concept with all repetitions >= 1 is mastered', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a')],
        quizItems: [
          _quiz('q1', 'a', repetitions: 1),
          _quiz('q2', 'a', repetitions: 3),
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptMastered('a'), isTrue);
    });

    test('concept with any repetitions == 0 is not mastered', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a')],
        quizItems: [
          _quiz('q1', 'a', repetitions: 1),
          _quiz('q2', 'a', repetitions: 0),
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptMastered('a'), isFalse);
    });

    test('unknown concept is mastered (no quiz items)', () {
      final graph = KnowledgeGraph(concepts: [_concept('a')]);
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptMastered('nonexistent'), isTrue);
    });
  });

  group('isConceptUnlocked', () {
    test('concept with no prerequisites is unlocked', () {
      final graph = KnowledgeGraph(concepts: [_concept('a')]);
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptUnlocked('a'), isTrue);
    });

    test('concept unlocked when prerequisite is mastered', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_rel('a', 'b')], // a depends on b
        quizItems: [_quiz('q1', 'b', repetitions: 1)],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptUnlocked('a'), isTrue);
    });

    test('concept locked when prerequisite is not mastered', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_rel('a', 'b')], // a depends on b
        quizItems: [_quiz('q1', 'b', repetitions: 0)],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptUnlocked('a'), isFalse);
    });

    test('transitive chain: c locked until b mastered', () {
      // c depends on b, b depends on a
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b'), _concept('c')],
        relationships: [_rel('c', 'b'), _rel('b', 'a')],
        quizItems: [
          _quiz('q1', 'a', repetitions: 1), // a mastered
          _quiz('q2', 'b', repetitions: 0), // b not mastered
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.isConceptUnlocked('a'), isTrue);
      expect(analyzer.isConceptUnlocked('b'), isTrue); // a is mastered
      expect(analyzer.isConceptUnlocked('c'), isFalse); // b not mastered
    });
  });

  group('foundational / unlocked / locked', () {
    // compose depends on containers, containers depends on images
    final graph = KnowledgeGraph(
      concepts: [
        _concept('compose'),
        _concept('containers'),
        _concept('images'),
      ],
      relationships: [
        _rel('compose', 'containers'),
        _rel('containers', 'images'),
      ],
      quizItems: [
        _quiz('q1', 'images', repetitions: 0),
        _quiz('q2', 'containers', repetitions: 0),
        _quiz('q3', 'compose', repetitions: 0),
      ],
    );
    final analyzer = GraphAnalyzer(graph);

    test('foundationalConcepts are those with no prerequisites', () {
      expect(analyzer.foundationalConcepts, ['images']);
    });

    test('unlockedConcepts includes only images (nothing mastered)', () {
      expect(analyzer.unlockedConcepts, ['images']);
    });

    test('lockedConcepts includes concepts with unmastered prerequisites', () {
      expect(
        analyzer.lockedConcepts,
        unorderedEquals(['compose', 'containers']),
      );
    });
  });

  group('topologicalSort', () {
    test('returns ordered list for acyclic graph', () {
      final graph = KnowledgeGraph(
        concepts: [
          _concept('compose'),
          _concept('containers'),
          _concept('images'),
        ],
        relationships: [
          _rel('compose', 'containers'),
          _rel('containers', 'images'),
        ],
      );
      final analyzer = GraphAnalyzer(graph);
      final sorted = analyzer.topologicalSort();

      expect(sorted, isNotNull);
      // images before containers before compose
      expect(sorted!.indexOf('images'), lessThan(sorted.indexOf('containers')));
      expect(sorted.indexOf('containers'), lessThan(sorted.indexOf('compose')));
    });

    test('returns null for cyclic graph', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_rel('a', 'b'), _rel('b', 'a')],
      );
      final analyzer = GraphAnalyzer(graph);
      expect(analyzer.topologicalSort(), isNull);
    });

    test('graph with no dependency edges sorts all concepts', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b'), _concept('c')],
        relationships: [_rel('a', 'b', label: 'is a type of')],
      );
      final analyzer = GraphAnalyzer(graph);
      final sorted = analyzer.topologicalSort();
      expect(sorted, isNotNull);
      expect(sorted, hasLength(3));
    });
  });

  group('hasCycles', () {
    test('false for acyclic graph', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_rel('a', 'b')],
      );
      expect(GraphAnalyzer(graph).hasCycles(), isFalse);
    });

    test('true for cyclic graph', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_rel('a', 'b'), _rel('b', 'a')],
      );
      expect(GraphAnalyzer(graph).hasCycles(), isTrue);
    });

    test('false for empty graph', () {
      expect(GraphAnalyzer(KnowledgeGraph.empty).hasCycles(), isFalse);
    });
  });
}
