import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/ui/helpers/graph_data_mapper.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  group('GraphDataMapper', () {
    group('masteryStateOf', () {
      test('locked when prerequisites not mastered', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'prereq', name: 'P', description: 'D', sourceDocumentId: 'doc1'),
            Concept(id: 'dep', name: 'D', description: 'D', sourceDocumentId: 'doc1'),
          ],
          relationships: [
            Relationship(id: 'r1', fromConceptId: 'dep', toConceptId: 'prereq', label: 'depends on'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'prereq', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 0, repetitions: 0,
                nextReview: '2020-01-01T00:00:00.000Z', lastReview: null),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('dep', graph, analyzer),
          MasteryState.locked,
        );
      });

      test('due when unlocked but no reviews', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 0, repetitions: 0,
                nextReview: '2020-01-01T00:00:00.000Z', lastReview: null),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('c1', graph, analyzer),
          MasteryState.due,
        );
      });

      test('learning when reviewed but interval < 21', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 6, repetitions: 2,
                nextReview: '2099-01-01T00:00:00.000Z', lastReview: null),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('c1', graph, analyzer),
          MasteryState.learning,
        );
      });

      test('mastered when interval >= 21 and recently reviewed', () {
        final now = DateTime.utc(2025, 6, 15);
        final recentReview = DateTime.utc(2025, 6, 10).toIso8601String();
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 25, repetitions: 5,
                nextReview: '2099-01-01T00:00:00.000Z', lastReview: recentReview),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('c1', graph, analyzer, now: now),
          MasteryState.mastered,
        );
      });

      test('mastered when interval >= 21 and no lastReview', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 25, repetitions: 5,
                nextReview: '2099-01-01T00:00:00.000Z', lastReview: null),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('c1', graph, analyzer),
          MasteryState.mastered,
        );
      });

      test('fading when mastered but lastReview > 30 days ago', () {
        final now = DateTime.utc(2025, 6, 15);
        final oldReview = DateTime.utc(2025, 5, 1).toIso8601String(); // 45 days ago
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 25, repetitions: 5,
                nextReview: '2099-01-01T00:00:00.000Z', lastReview: oldReview),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('c1', graph, analyzer, now: now),
          MasteryState.fading,
        );
      });

      test('mastered when no quiz items (informational node)', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
        );
        final analyzer = GraphAnalyzer(graph);

        expect(
          GraphDataMapper.masteryStateOf('c1', graph, analyzer),
          MasteryState.mastered,
        );
      });
    });

    group('freshnessOf', () {
      test('returns 1.0 for just reviewed (0 days)', () {
        final now = DateTime.utc(2025, 6, 15);
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 25, repetitions: 5,
                nextReview: '2099-01-01T00:00:00.000Z',
                lastReview: now.toIso8601String()),
          ],
        );

        expect(
          GraphDataMapper.freshnessOf('c1', graph, now: now),
          closeTo(1.0, 0.01),
        );
      });

      test('returns ~0.65 for 30 days ago', () {
        final now = DateTime.utc(2025, 6, 15);
        final thirtyDaysAgo = DateTime.utc(2025, 5, 16).toIso8601String();
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 25, repetitions: 5,
                nextReview: '2099-01-01T00:00:00.000Z',
                lastReview: thirtyDaysAgo),
          ],
        );

        expect(
          GraphDataMapper.freshnessOf('c1', graph, now: now),
          closeTo(0.65, 0.02),
        );
      });

      test('returns 0.3 for 60+ days ago', () {
        final now = DateTime.utc(2025, 6, 15);
        final sixtyDaysAgo = DateTime.utc(2025, 4, 16).toIso8601String();
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 25, repetitions: 5,
                nextReview: '2099-01-01T00:00:00.000Z',
                lastReview: sixtyDaysAgo),
          ],
        );

        expect(
          GraphDataMapper.freshnessOf('c1', graph, now: now),
          closeTo(0.3, 0.02),
        );
      });

      test('returns 1.0 when no lastReview', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'C', description: 'D', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.',
                easeFactor: 2.5, interval: 0, repetitions: 0,
                nextReview: '2020-01-01T00:00:00.000Z', lastReview: null),
          ],
        );

        expect(GraphDataMapper.freshnessOf('c1', graph), 1.0);
      });
    });

    group('toGraphViewData', () {
      test('maps concepts to vertexes with mastery tags', () {
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'Docker', description: 'Containers', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem.newCard(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.'),
          ],
        );

        final data = GraphDataMapper.toGraphViewData(graph);
        final vertexes = data['vertexes'] as List;

        expect(vertexes, hasLength(1));
        expect((vertexes[0] as Map)['id'], 'c1');
        expect((vertexes[0] as Map)['tag'], 'due');
      });

      test('vertex data includes freshness', () {
        final graph = KnowledgeGraph(
          concepts: const [
            Concept(id: 'c1', name: 'Docker', description: 'Containers', sourceDocumentId: 'doc1'),
          ],
          quizItems: [
            QuizItem.newCard(id: 'q1', conceptId: 'c1', question: 'Q?', answer: 'A.'),
          ],
        );

        final data = GraphDataMapper.toGraphViewData(graph);
        final vertexes = data['vertexes'] as List;
        final vertexData = (vertexes[0] as Map)['data'] as Map;

        expect(vertexData.containsKey('freshness'), isTrue);
        expect(vertexData['freshness'], isA<double>());
      });

      test('maps relationships to edges', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'A', description: 'D', sourceDocumentId: 'doc1'),
            Concept(id: 'c2', name: 'B', description: 'D', sourceDocumentId: 'doc1'),
          ],
          relationships: [
            Relationship(id: 'r1', fromConceptId: 'c2', toConceptId: 'c1', label: 'depends on'),
          ],
        );

        final data = GraphDataMapper.toGraphViewData(graph);
        final edges = data['edges'] as List;

        expect(edges, hasLength(1));
        expect((edges[0] as Map)['srcId'], 'c2');
        expect((edges[0] as Map)['dstId'], 'c1');
        expect((edges[0] as Map)['ranking'], 100); // dependency edge
      });

      test('non-dependency edges get lower ranking', () {
        const graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'c1', name: 'A', description: 'D', sourceDocumentId: 'doc1'),
            Concept(id: 'c2', name: 'B', description: 'D', sourceDocumentId: 'doc1'),
          ],
          relationships: [
            Relationship(id: 'r1', fromConceptId: 'c1', toConceptId: 'c2', label: 'related to'),
          ],
        );

        final data = GraphDataMapper.toGraphViewData(graph);
        final edges = data['edges'] as List;

        expect((edges[0] as Map)['ranking'], 50);
      });
    });

    test('tagColorMap has all five states', () {
      final map = GraphDataMapper.tagColorMap;
      expect(map, hasLength(5));
      expect(map['locked'], Colors.grey);
      expect(map['due'], Colors.red);
      expect(map['learning'], Colors.amber);
      expect(map['mastered'], Colors.green);
      expect(map['fading'], const Color(0xFF81C784));
    });
  });
}
