import 'package:engram/src/engine/gap_analyzer.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/concept_cluster.dart';
import 'package:engram/src/models/knowledge_gap.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/quiz_item_helpers.dart';

void main() {
  group('GapAnalyzer', () {
    test('empty graph returns no gaps', () {
      final graph = KnowledgeGraph();
      final gaps = GapAnalyzer(graph).analyze();
      expect(gaps, isEmpty);
    });

    test('single connected cluster returns no cluster isolation gap', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'A',
            description: 'desc',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'B',
            description: 'desc',
            sourceDocumentId: 'd',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'related to',
            type: RelationshipType.relatedTo,
          ),
        ],
      );
      final gaps = GapAnalyzer(graph).analyze();
      final isolationGaps = gaps.where(
        (g) => g.type == GapType.clusterIsolation,
      );
      expect(isolationGaps, isEmpty);
    });

    group('cluster isolation', () {
      test('two disconnected clusters produce a cluster isolation gap', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'a',
              name: 'Alpha',
              description: 'desc',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'b',
              name: 'Beta',
              description: 'desc',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'c',
              name: 'Gamma',
              description: 'desc',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'd',
              name: 'Delta',
              description: 'desc',
              sourceDocumentId: 'd',
            ),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'c',
              toConceptId: 'd',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final isolationGaps =
            gaps.where((g) => g.type == GapType.clusterIsolation).toList();

        expect(isolationGaps, hasLength(1));
        expect(isolationGaps.first.severity, greaterThan(0));
        expect(isolationGaps.first.involvedClusterLabels, hasLength(2));
      });

      test('severity scales with product of cluster sizes', () {
        // Two pairs (2×2=4) vs one pair + one triple (2×3=6)
        final smallGraph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
            Concept(id: 'd', name: 'D', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'c',
              toConceptId: 'd',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
        );

        final largeGraph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
            Concept(id: 'd', name: 'D', description: '', sourceDocumentId: 'd'),
            Concept(id: 'e', name: 'E', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'c',
              toConceptId: 'd',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
            const Relationship(
              id: 'r3',
              fromConceptId: 'd',
              toConceptId: 'e',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
        );

        final smallGaps = GapAnalyzer(smallGraph).analyze();
        final largeGaps = GapAnalyzer(largeGraph).analyze();

        final smallIsolation = smallGaps.firstWhere(
          (g) => g.type == GapType.clusterIsolation,
        );
        final largeIsolation = largeGaps.firstWhere(
          (g) => g.type == GapType.clusterIsolation,
        );

        expect(largeIsolation.severity, greaterThan(smallIsolation.severity));
      });

      test('search terms combine concept names from both clusters', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'a',
              name: 'Machine Learning',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'b',
              name: 'Neural Networks',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'c',
              name: 'Database Design',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'd',
              name: 'SQL Joins',
              description: '',
              sourceDocumentId: 'd',
            ),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'c',
              toConceptId: 'd',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final isolation = gaps.firstWhere(
          (g) => g.type == GapType.clusterIsolation,
        );

        expect(isolation.suggestedSearchTerms, isNotEmpty);
      });
    });

    group('structural thinness', () {
      test('concept with degree 0 and quiz items is flagged', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'a',
              name: 'Isolated',
              description: 'important',
              sourceDocumentId: 'd',
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'a')],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final thinGaps = gaps.where(
          (g) => g.type == GapType.structuralThinness,
        );

        expect(thinGaps, hasLength(1));
        expect(thinGaps.first.involvedConceptIds, contains('a'));
      });

      test('concept with degree 1 and quiz items is flagged', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'a',
              name: 'Hub',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'b',
              name: 'Thin',
              description: '',
              sourceDocumentId: 'd',
            ),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'b')],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final thinGaps =
            gaps.where((g) => g.type == GapType.structuralThinness).toList();

        expect(thinGaps.any((g) => g.involvedConceptIds.contains('b')), isTrue);
      });

      test('concept with no quiz items is not flagged for thinness', () {
        // Informational nodes without quiz items are leaf-like by design.
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'a',
              name: 'Info',
              description: '',
              sourceDocumentId: 'd',
            ),
          ],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final thinGaps = gaps.where(
          (g) => g.type == GapType.structuralThinness,
        );

        expect(thinGaps, isEmpty);
      });

      test('well-connected concept is not flagged', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'a',
              toConceptId: 'c',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'a')],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final thinGaps = gaps.where(
          (g) => g.type == GapType.structuralThinness,
        );

        // a has degree 2, should not be flagged
        expect(
          thinGaps.any((g) => g.involvedConceptIds.contains('a')),
          isFalse,
        );
      });
    });

    group('relationship type gaps', () {
      test('all-prerequisite cluster is flagged', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'b',
              toConceptId: 'a',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'c',
              toConceptId: 'b',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
          ],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final typeGaps = gaps.where(
          (g) => g.type == GapType.relationshipTypeGap,
        );

        expect(typeGaps, isNotEmpty);
      });

      test('cluster with lateral relationships is not flagged', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'b',
              toConceptId: 'a',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'a',
              toConceptId: 'c',
              label: 'is analogous to',
              type: RelationshipType.analogy,
            ),
          ],
        );

        final gaps = GapAnalyzer(graph).analyze();
        final typeGaps = gaps.where(
          (g) => g.type == GapType.relationshipTypeGap,
        );

        expect(typeGaps, isEmpty);
      });
    });

    group('critical bottlenecks', () {
      test('high out-degree low-mastery concept is flagged', () {
        final now = DateTime.utc(2026, 2, 20);
        // Concept 'hub' has many dependents but low mastery (unreviewed).
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'hub',
              name: 'Hub',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'dep1',
              name: 'Dep1',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'dep2',
              name: 'Dep2',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'dep3',
              name: 'Dep3',
              description: '',
              sourceDocumentId: 'd',
            ),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'dep1',
              toConceptId: 'hub',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'dep2',
              toConceptId: 'hub',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r3',
              fromConceptId: 'dep3',
              toConceptId: 'hub',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
          ],
          quizItems: [
            // hub has unreviewed quiz item → low mastery
            testQuizItem(id: 'q1', conceptId: 'hub', lastReview: null),
          ],
        );

        final gaps = GapAnalyzer(graph, now: now).analyze();
        final bottlenecks = gaps.where(
          (g) => g.type == GapType.criticalBottleneck,
        );

        expect(bottlenecks, isNotEmpty);
        expect(bottlenecks.first.involvedConceptIds, contains('hub'));
      });

      test('high out-degree mastered concept is not flagged', () {
        final now = DateTime.utc(2026, 2, 20);
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'hub',
              name: 'Hub',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'dep1',
              name: 'Dep1',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'dep2',
              name: 'Dep2',
              description: '',
              sourceDocumentId: 'd',
            ),
            Concept(
              id: 'dep3',
              name: 'Dep3',
              description: '',
              sourceDocumentId: 'd',
            ),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'dep1',
              toConceptId: 'hub',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'dep2',
              toConceptId: 'hub',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r3',
              fromConceptId: 'dep3',
              toConceptId: 'hub',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
          ],
          quizItems: [
            masteredQuizItem(
              id: 'q1',
              conceptId: 'hub',
              lastReview: DateTime.utc(2026, 2, 18),
            ),
          ],
        );

        final gaps = GapAnalyzer(graph, now: now).analyze();
        final bottlenecks = gaps.where(
          (g) => g.type == GapType.criticalBottleneck,
        );

        expect(bottlenecks, isEmpty);
      });
    });

    group('sorting and search terms', () {
      test('gaps are sorted by severity descending', () {
        // Build a graph that produces multiple gap types
        final graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
            Concept(id: 'd', name: 'D', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            // Two disconnected clusters (a-b) and (c-d)
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
            const Relationship(
              id: 'r2',
              fromConceptId: 'c',
              toConceptId: 'd',
              label: 'depends on',
              type: RelationshipType.prerequisite,
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'a')],
        );

        final gaps = GapAnalyzer(graph).analyze();

        // Should be sorted descending by severity
        for (var i = 1; i < gaps.length; i++) {
          expect(
            gaps[i - 1].severity,
            greaterThanOrEqualTo(gaps[i].severity),
            reason:
                'Gap at index ${i - 1} should have >= severity than gap at $i',
          );
        }
      });

      test('search terms are derived from concept names', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(
              id: 'a',
              name: 'Neural Networks',
              description: '',
              sourceDocumentId: 'd',
            ),
          ],
          quizItems: [testQuizItem(id: 'q1', conceptId: 'a')],
        );

        final gaps = GapAnalyzer(graph).analyze();
        // Structural thinness gap for isolated concept with quiz items
        final thinGap = gaps.firstWhere(
          (g) => g.type == GapType.structuralThinness,
        );

        expect(thinGap.suggestedSearchTerms, contains('Neural Networks'));
      });
    });

    group('accepts precomputed clusters', () {
      test('uses provided clusters instead of detecting', () {
        final graph = KnowledgeGraph(
          concepts: [
            Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
            Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
            Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
          ],
          relationships: [
            const Relationship(
              id: 'r1',
              fromConceptId: 'a',
              toConceptId: 'b',
              label: 'related to',
              type: RelationshipType.relatedTo,
            ),
          ],
        );

        // Pre-assign clusters: {a, b} and {c}
        final clusters = [
          ConceptCluster(label: 'Cluster AB', conceptIds: ['a', 'b']),
          ConceptCluster(label: 'Cluster C', conceptIds: ['c']),
        ];

        final gaps = GapAnalyzer(graph, clusters: clusters).analyze();
        final isolation = gaps.where((g) => g.type == GapType.clusterIsolation);

        expect(isolation, isNotEmpty);
        expect(
          isolation.first.involvedClusterLabels,
          containsAll(['Cluster AB', 'Cluster C']),
        );
      });
    });
  });
}
