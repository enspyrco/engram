import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/engine/mastery_state.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/network_health.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/ui/graph/graph_edge.dart';
import 'package:engram/src/ui/graph/graph_node.dart';
import 'package:engram/src/ui/graph/particle_system.dart';
import 'package:test/test.dart';

List<GraphEdge> _makeEdges() {
  const graph = KnowledgeGraph(
    concepts: [
      Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
      Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
    ],
    relationships: [
      Relationship(id: 'r1', fromConceptId: 'a', toConceptId: 'b', label: 'relates to'),
    ],
  );

  final analyzer = GraphAnalyzer(graph);
  final nodeA = GraphNode(
    concept: graph.concepts[0],
    masteryState: masteryStateOf('a', graph, analyzer),
    freshness: 1.0,
  );
  final nodeB = GraphNode(
    concept: graph.concepts[1],
    masteryState: masteryStateOf('b', graph, analyzer),
    freshness: 1.0,
  );

  return [
    GraphEdge(
      relationship: graph.relationships[0],
      source: nodeA,
      target: nodeB,
    ),
  ];
}

void main() {
  group('ParticleSystem', () {
    test('initialize creates particles for healthy tier', () {
      final system = ParticleSystem(seed: 42);
      final edges = _makeEdges();

      system.initialize(edges, HealthTier.healthy);

      expect(system.particles, isNotEmpty);
      // Healthy = 2 particles per edge
      expect(system.particles.length, 2);
    });

    test('initialize creates fewer particles for brownout', () {
      final system = ParticleSystem(seed: 42);
      final edges = _makeEdges();

      system.initialize(edges, HealthTier.brownout);

      expect(system.particles.length, 1);
    });

    test('initialize creates no particles for fracture', () {
      final system = ParticleSystem(seed: 42);
      final edges = _makeEdges();

      system.initialize(edges, HealthTier.fracture);

      expect(system.particles, isEmpty);
    });

    test('step advances particle positions', () {
      final system = ParticleSystem(seed: 42);
      final edges = _makeEdges();

      system.initialize(edges, HealthTier.healthy);

      final beforePositions =
          system.particles.map((p) => p.progress).toList();

      system.step(HealthTier.healthy);

      final afterPositions =
          system.particles.map((p) => p.progress).toList();

      // At least one particle should have moved
      final moved = Iterable.generate(beforePositions.length).any(
        (i) => (afterPositions[i] - beforePositions[i]).abs() > 0.001,
      );
      expect(moved, isTrue);
    });

    test('particles wrap around at 1.0', () {
      final system = ParticleSystem(seed: 42);
      final edges = _makeEdges();

      system.initialize(edges, HealthTier.healthy);

      // Run many steps to ensure wrap-around
      for (var i = 0; i < 200; i++) {
        system.step(HealthTier.healthy);
      }

      for (final particle in system.particles) {
        expect(particle.progress, greaterThanOrEqualTo(0.0));
        expect(particle.progress, lessThan(1.0));
      }
    });

    test('reinitialize clears old particles', () {
      final system = ParticleSystem(seed: 42);
      final edges = _makeEdges();

      system.initialize(edges, HealthTier.healthy);
      expect(system.particles, hasLength(2));

      system.initialize(edges, HealthTier.fracture);
      expect(system.particles, isEmpty);
    });
  });
}
