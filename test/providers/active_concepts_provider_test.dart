import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/narration_session.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/providers/active_concepts_provider.dart';
import 'package:engram/src/providers/graph_structure_provider.dart';
import 'package:engram/src/providers/narration_provider.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  //
  // Test graph:
  //   A --- B --- C
  //
  final testGraph = KnowledgeGraph(
    concepts: [
      Concept(id: 'a', name: 'A', description: 'D', sourceDocumentId: 'doc'),
      Concept(id: 'b', name: 'B', description: 'D', sourceDocumentId: 'doc'),
      Concept(id: 'c', name: 'C', description: 'D', sourceDocumentId: 'doc'),
    ],
    relationships: [
      const Relationship(
        id: 'r1',
        fromConceptId: 'a',
        toConceptId: 'b',
        label: 'related',
      ),
      const Relationship(
        id: 'r2',
        fromConceptId: 'b',
        toConceptId: 'c',
        label: 'related',
      ),
    ],
  );

  group('activeConceptsProvider', () {
    test('returns empty map when narration is idle', () {
      final container = ProviderContainer(
        overrides: [
          narrationProvider.overrideWith(
            () => _FakeNarrationNotifier(const NarrationSession()),
          ),
          graphStructureProvider.overrideWithValue(testGraph),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(activeConceptsProvider);
      expect(result, isEmpty);
    });

    test('returns propagated intensities when narration is playing', () {
      final session = NarrationSession(
        phase: NarrationPhase.playing,
        activeConcepts: ISet(const {'a'}),
      );

      final container = ProviderContainer(
        overrides: [
          narrationProvider.overrideWith(() => _FakeNarrationNotifier(session)),
          graphStructureProvider.overrideWithValue(testGraph),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(activeConceptsProvider);

      // 'a' is active → 1.0
      expect(result['a'], 1.0);
      // 'b' is depth-1 from 'a' → 0.4
      expect(result['b'], 0.4);
      // 'c' is depth-2 from 'a' → 0.15
      expect(result['c'], 0.15);
    });

    test('returns empty map when graph is null', () {
      final session = NarrationSession(
        phase: NarrationPhase.playing,
        activeConcepts: ISet(const {'a'}),
      );

      final container = ProviderContainer(
        overrides: [
          narrationProvider.overrideWith(() => _FakeNarrationNotifier(session)),
          graphStructureProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(activeConceptsProvider);
      expect(result, isEmpty);
    });

    test('returns empty map when active concepts is empty during playback', () {
      const session = NarrationSession(
        phase: NarrationPhase.playing,
        // No active concepts (between concept mentions).
      );

      final container = ProviderContainer(
        overrides: [
          narrationProvider.overrideWith(() => _FakeNarrationNotifier(session)),
          graphStructureProvider.overrideWithValue(testGraph),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(activeConceptsProvider);
      expect(result, isEmpty);
    });

    test('handles multiple active concepts with merged propagation', () {
      // Both 'a' and 'c' active — 'b' is depth-1 from both → max 0.4
      final session = NarrationSession(
        phase: NarrationPhase.playing,
        activeConcepts: ISet(const {'a', 'c'}),
      );

      final container = ProviderContainer(
        overrides: [
          narrationProvider.overrideWith(() => _FakeNarrationNotifier(session)),
          graphStructureProvider.overrideWithValue(testGraph),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(activeConceptsProvider);

      expect(result['a'], 1.0);
      expect(result['c'], 1.0);
      expect(result['b'], 0.4); // depth-1 from both
    });
  });
}

/// Fake notifier that returns a fixed [NarrationSession].
class _FakeNarrationNotifier extends Notifier<NarrationSession>
    implements NarrationNotifier {
  _FakeNarrationNotifier(this._state);

  final NarrationSession _state;

  @override
  NarrationSession build() => _state;

  @override
  Future<void> generateNarration({
    required List<dynamic> concepts,
    required List<dynamic> relationships,
  }) async {}

  @override
  void play() {}

  @override
  void pause() {}

  @override
  void seek(Duration position) {}

  @override
  void reset() {}
}
