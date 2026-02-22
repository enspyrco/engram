import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/concept_cluster.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/network_health.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/models/repair_mission.dart';
import 'package:engram/src/providers/catastrophe_provider.dart';
import 'package:engram/src/providers/desired_retention_provider.dart';
import 'package:engram/src/providers/guardian_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/network_health_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

Concept _concept(String id) => Concept(
  id: id,
  name: id,
  description: 'desc',
  sourceDocumentId: 'doc1',
);

Relationship _rel(String from, String to) => Relationship(
  id: '$from-$to',
  fromConceptId: from,
  toConceptId: to,
  label: 'depends on',
);

ProviderContainer _container({
  required KnowledgeGraph graph,
  GuardianState? guardianState,
  CatastropheState? catastropheState,
}) {
  return ProviderContainer(
    overrides: [
      knowledgeGraphProvider.overrideWith(() => _FakeGraphNotifier(graph)),
      guardianProvider.overrideWith(() => _FakeGuardianNotifier(
        guardianState ?? GuardianState(),
      )),
      catastropheProvider.overrideWith(() => _FakeCatastropheNotifier(
        catastropheState ?? CatastropheState(),
      )),
      // Network health isn't watched by desiredRetentionProvider directly,
      // but catastrophe/guardian notifiers may reference it in build().
      // Override to avoid cascading provider failures.
      networkHealthProvider.overrideWithValue(
        const NetworkHealth(score: 1.0, tier: HealthTier.healthy),
      ),
    ],
  );
}

void main() {
  group('desiredRetentionProvider', () {
    test('empty graph returns empty map', () async {
      final container = _container(graph: KnowledgeGraph.empty);
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      expect(container.read(desiredRetentionProvider), isEmpty);
    });

    test('hub concept (3+ dependents) gets 0.95', () async {
      // 'hub' is depended on by a, b, c
      final graph = KnowledgeGraph(
        concepts: [
          _concept('hub'),
          _concept('a'),
          _concept('b'),
          _concept('c'),
        ],
        relationships: [
          _rel('a', 'hub'),
          _rel('b', 'hub'),
          _rel('c', 'hub'),
        ],
      );
      final container = _container(graph: graph);
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      final retention = container.read(desiredRetentionProvider);
      expect(retention['hub'], elevatedRetention);
    });

    test('leaf concept (0 dependents) gets 0.85', () async {
      // 'leaf' depends on 'root' but nobody depends on 'leaf'
      final graph = KnowledgeGraph(
        concepts: [_concept('root'), _concept('leaf')],
        relationships: [_rel('leaf', 'root')],
      );
      final container = _container(graph: graph);
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      final retention = container.read(desiredRetentionProvider);
      expect(retention['leaf'], leafRetention);
    });

    test('standard concept (1-2 dependents) gets 0.90', () async {
      // 'mid' is depended on by 'top', and depends on 'base'
      final graph = KnowledgeGraph(
        concepts: [_concept('base'), _concept('mid'), _concept('top')],
        relationships: [_rel('mid', 'base'), _rel('top', 'mid')],
      );
      final container = _container(graph: graph);
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      final retention = container.read(desiredRetentionProvider);
      expect(retention['mid'], standardRetention);
    });

    test('guardian-protected concept gets 0.97 (overrides hub/leaf)', () async {
      final graph = KnowledgeGraph(
        concepts: [_concept('guarded'), _concept('dep')],
        relationships: [_rel('dep', 'guarded')],
      );
      final container = _container(
        graph: graph,
        guardianState: GuardianState(
          clusters: [
            ConceptCluster(
              label: 'cluster1',
              conceptIds: ['guarded'],
              guardianUid: 'me',
            ),
          ],
          currentUid: 'me',
        ),
      );
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      final retention = container.read(desiredRetentionProvider);
      expect(retention['guarded'], guardianRetention);
    });

    test('mission target gets 0.95 (elevated from standard/leaf)', () async {
      final graph = KnowledgeGraph(
        concepts: [_concept('target')],
      );
      final container = _container(
        graph: graph,
        catastropheState: CatastropheState(
          activeMissions: [
            RepairMission(
              id: 'm1',
              conceptIds: ['target'],
              createdAt: DateTime.utc(2025, 6, 15),
            ),
          ],
        ),
      );
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      final retention = container.read(desiredRetentionProvider);
      // 'target' has 0 dependents → would be leaf, but mission elevates it
      expect(retention['target'], elevatedRetention);
    });

    test('guardian takes precedence over mission', () async {
      final graph = KnowledgeGraph(
        concepts: [_concept('both')],
      );
      final container = _container(
        graph: graph,
        guardianState: GuardianState(
          clusters: [
            ConceptCluster(
              label: 'c1',
              conceptIds: ['both'],
              guardianUid: 'me',
            ),
          ],
          currentUid: 'me',
        ),
        catastropheState: CatastropheState(
          activeMissions: [
            RepairMission(
              id: 'm1',
              conceptIds: ['both'],
              createdAt: DateTime.utc(2025, 6, 15),
            ),
          ],
        ),
      );
      addTearDown(container.dispose);
      await container.read(knowledgeGraphProvider.future);

      final retention = container.read(desiredRetentionProvider);
      expect(retention['both'], guardianRetention); // guardian wins
    });
  });
}

class _FakeGraphNotifier extends KnowledgeGraphNotifier {
  _FakeGraphNotifier(this._graph);
  final KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;
}

class _FakeGuardianNotifier extends GuardianNotifier {
  _FakeGuardianNotifier(this._state);
  final GuardianState _state;

  @override
  GuardianState build() => _state;
}

class _FakeCatastropheNotifier extends CatastropheNotifier {
  _FakeCatastropheNotifier(this._state);
  final CatastropheState _state;

  @override
  CatastropheState build() => _state;
}
