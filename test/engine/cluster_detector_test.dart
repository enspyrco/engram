import 'package:engram/src/engine/cluster_detector.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

void main() {
  group('ClusterDetector', () {
    test('returns empty for empty graph', () {
      final graph = KnowledgeGraph();
      final clusters = ClusterDetector(graph).detect();
      expect(clusters, isEmpty);
    });

    test('each isolated node gets its own cluster', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
          Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
        ],
      );

      final clusters = ClusterDetector(graph).detect();
      expect(clusters, hasLength(3));
    });

    test('connected components merge into one cluster', () {
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
            label: 'relates to',
          ),
          const Relationship(
            id: 'r2',
            fromConceptId: 'b',
            toConceptId: 'c',
            label: 'relates to',
          ),
        ],
      );

      final clusters = ClusterDetector(graph).detect();
      expect(clusters, hasLength(1));
      expect(clusters.first.conceptIds, containsAll(['a', 'b', 'c']));
    });

    test('detects two separate clusters', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
          Concept(id: 'x', name: 'X', description: '', sourceDocumentId: 'd'),
          Concept(id: 'y', name: 'Y', description: '', sourceDocumentId: 'd'),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'relates to',
          ),
          const Relationship(
            id: 'r2',
            fromConceptId: 'x',
            toConceptId: 'y',
            label: 'relates to',
          ),
        ],
      );

      final clusters = ClusterDetector(graph).detect();
      expect(clusters, hasLength(2));

      final labels = clusters.map((c) => c.label).toSet();
      // Each cluster should be labeled by its most connected concept
      expect(labels, hasLength(2));
    });

    test('cluster label is the most-connected concept name', () {
      // Hub 'b' has degree 3, others have degree 1
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Leaf-A',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Hub-B',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'c',
            name: 'Leaf-C',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'd',
            name: 'Leaf-D',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'relates to',
          ),
          const Relationship(
            id: 'r2',
            fromConceptId: 'c',
            toConceptId: 'b',
            label: 'relates to',
          ),
          const Relationship(
            id: 'r3',
            fromConceptId: 'd',
            toConceptId: 'b',
            label: 'relates to',
          ),
        ],
      );

      final clusters = ClusterDetector(graph).detect();
      expect(clusters, hasLength(1));
      expect(clusters.first.label, 'Hub-B');
    });

    test('deterministic: same graph produces same clusters', () {
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
            label: 'relates to',
          ),
          const Relationship(
            id: 'r2',
            fromConceptId: 'b',
            toConceptId: 'c',
            label: 'relates to',
          ),
        ],
      );

      final clusters1 = ClusterDetector(graph).detect();
      final clusters2 = ClusterDetector(graph).detect();

      expect(clusters1.length, clusters2.length);
      expect(clusters1.first.label, clusters2.first.label);
      expect(
        clusters1.first.conceptIds.toSet(),
        clusters2.first.conceptIds.toSet(),
      );
    });

    test('single concept returns one cluster', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
        ],
      );

      final clusters = ClusterDetector(graph).detect();
      expect(clusters, hasLength(1));
      expect(clusters.first.conceptIds, ['a']);
      expect(clusters.first.label, 'A');
    });
  });
}
