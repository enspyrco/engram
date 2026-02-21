import 'package:engram/src/models/concept_cluster.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/providers/guardian_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('GuardianProvider', () {
    test('initial state has empty clusters and null uid', () {
      // Without auth/settings, the provider returns empty state
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(KnowledgeGraph()),
          ),
          teamRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(guardianProvider);
      expect(state.clusters, isEmpty);
      expect(state.currentUid, isNull);
    });

    test('myGuardedClusters filters by currentUid', () {
      final state = GuardianState(
        clusters: [
          ConceptCluster(
            label: 'CI/CD',
            conceptIds: ['a', 'b'],
            guardianUid: 'me',
          ),
          ConceptCluster(
            label: 'Docker',
            conceptIds: ['c'],
            guardianUid: 'other',
          ),
          ConceptCluster(label: 'K8s', conceptIds: ['d']),
        ],
        currentUid: 'me',
      );

      final mine = state.myGuardedClusters;
      expect(mine, hasLength(1));
      expect(mine.first.label, 'CI/CD');
    });

    test('guardianForCluster looks up guardian UID by label', () {
      final state = GuardianState(
        clusters: [
          ConceptCluster(
            label: 'CI/CD',
            conceptIds: ['a'],
            guardianUid: 'user1',
          ),
          ConceptCluster(label: 'K8s', conceptIds: ['b']),
        ],
        currentUid: 'me',
      );

      expect(state.guardianForCluster('CI/CD'), 'user1');
      expect(state.guardianForCluster('K8s'), isNull);
      expect(state.guardianForCluster('nonexistent'), isNull);
    });

    test('copyWith preserves unspecified fields', () {
      final state = GuardianState(
        clusters: [
          ConceptCluster(label: 'A', conceptIds: ['a']),
        ],
        currentUid: 'me',
      );

      final updated = state.copyWith(currentUid: 'other');
      expect(updated.clusters, hasLength(1));
      expect(updated.currentUid, 'other');
    });

    test('myGuardedClusters returns empty when no uid', () {
      final state = GuardianState(
        clusters: [
          ConceptCluster(label: 'A', conceptIds: ['a'], guardianUid: 'someone'),
        ],
      );

      expect(state.myGuardedClusters, isEmpty);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._initial);
  final KnowledgeGraph _initial;
  @override
  Future<KnowledgeGraph> build() async => _initial;
}
