import 'package:engram/src/engine/neighborhood.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

void main() {
  final cA = Concept(
    id: 'a',
    name: 'Concept A',
    description: 'Center node',
    sourceDocumentId: 'doc1',
  );
  final cB = Concept(
    id: 'b',
    name: 'Concept B',
    description: 'Neighbor 1',
    sourceDocumentId: 'doc1',
  );
  final cC = Concept(
    id: 'c',
    name: 'Concept C',
    description: 'Neighbor 2',
    sourceDocumentId: 'doc1',
  );
  final cD = Concept(
    id: 'd',
    name: 'Concept D',
    description: '2-hop away',
    sourceDocumentId: 'doc1',
  );

  const rAB = Relationship(
    id: 'r-ab',
    fromConceptId: 'a',
    toConceptId: 'b',
    label: 'depends on',
    type: RelationshipType.prerequisite,
  );
  const rAC = Relationship(
    id: 'r-ac',
    fromConceptId: 'a',
    toConceptId: 'c',
    label: 'enables',
    type: RelationshipType.enables,
  );
  const rBC = Relationship(
    id: 'r-bc',
    fromConceptId: 'b',
    toConceptId: 'c',
    label: 'related to',
    type: RelationshipType.relatedTo,
  );
  const rCD = Relationship(
    id: 'r-cd',
    fromConceptId: 'c',
    toConceptId: 'd',
    label: 'part of',
    type: RelationshipType.composition,
  );

  group('neighborhoodOf', () {
    test('extracts center + 1-hop neighbors', () {
      final graph = KnowledgeGraph(
        concepts: [cA, cB, cC, cD],
        relationships: [rAB, rAC, rBC, rCD],
      );

      final hood = neighborhoodOf('a', graph);

      expect(hood.concepts.map((c) => c.id).toSet(), {'a', 'b', 'c'});
    });

    test('excludes 2-hop nodes', () {
      final graph = KnowledgeGraph(
        concepts: [cA, cB, cC, cD],
        relationships: [rAB, rAC, rBC, rCD],
      );

      final hood = neighborhoodOf('a', graph);

      expect(hood.concepts.map((c) => c.id), isNot(contains('d')));
    });

    test('includes edges between center and neighbors', () {
      final graph = KnowledgeGraph(
        concepts: [cA, cB, cC, cD],
        relationships: [rAB, rAC, rBC, rCD],
      );

      final hood = neighborhoodOf('a', graph);

      expect(hood.relationships.map((r) => r.id), contains('r-ab'));
      expect(hood.relationships.map((r) => r.id), contains('r-ac'));
    });

    test('includes edges between neighbors', () {
      final graph = KnowledgeGraph(
        concepts: [cA, cB, cC, cD],
        relationships: [rAB, rAC, rBC, rCD],
      );

      final hood = neighborhoodOf('a', graph);

      // B→C edge is included because both B and C are in the neighborhood.
      expect(hood.relationships.map((r) => r.id), contains('r-bc'));
    });

    test('excludes edges to 2-hop nodes', () {
      final graph = KnowledgeGraph(
        concepts: [cA, cB, cC, cD],
        relationships: [rAB, rAC, rBC, rCD],
      );

      final hood = neighborhoodOf('a', graph);

      // C→D edge is excluded because D is outside the 1-hop neighborhood.
      expect(hood.relationships.map((r) => r.id), isNot(contains('r-cd')));
    });

    test('returns empty graph for unknown concept', () {
      final graph = KnowledgeGraph(concepts: [cA, cB], relationships: [rAB]);

      final hood = neighborhoodOf('unknown', graph);

      expect(hood.concepts, isEmpty);
      expect(hood.relationships, isEmpty);
    });

    test('returns single-concept graph for isolated node', () {
      final graph = KnowledgeGraph(concepts: [cA, cB, cC]);

      final hood = neighborhoodOf('a', graph);

      expect(hood.concepts.length, 1);
      expect(hood.concepts.first.id, 'a');
      expect(hood.relationships, isEmpty);
    });

    test('includes incoming edges (target as toConceptId)', () {
      // B → A (A is the target, found via toConceptId)
      const rBA = Relationship(
        id: 'r-ba',
        fromConceptId: 'b',
        toConceptId: 'a',
        label: 'type of',
        type: RelationshipType.generalization,
      );
      final graph = KnowledgeGraph(
        concepts: [cA, cB, cC],
        relationships: [rBA],
      );

      final hood = neighborhoodOf('a', graph);

      expect(hood.concepts.map((c) => c.id).toSet(), {'a', 'b'});
      expect(hood.relationships.map((r) => r.id), contains('r-ba'));
    });
  });
}
