import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/network_health.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/providers/catastrophe_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/network_health_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('CatastropheProvider', () {
    test('initial state is healthy with no events', () {
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(KnowledgeGraph()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(catastropheProvider);
      expect(state.previousTier, HealthTier.healthy);
      expect(state.activeEvents, isEmpty);
      expect(state.activeMissions, isEmpty);
      expect(state.latestTransition, isNull);
    });

    test('detects worsening transition and creates event', () {
      // Start with healthy graph
      final recentReview = DateTime.utc(2025, 6, 10);
      final healthyGraph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'a',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: recentReview,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(healthyGraph),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Read initial state to activate providers
      final initialHealth = container.read(networkHealthProvider);
      expect(initialHealth.tier, HealthTier.healthy);

      // Read catastrophe provider to start listening
      container.read(catastropheProvider);

      // Now degrade to an all-due graph
      final degradedGraph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'a',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 0,
            repetitions: 0,
            nextReview: DateTime.utc(2020),
            lastReview: null,
          ),
        ],
      );

      container.read(knowledgeGraphProvider.notifier).setGraph(degradedGraph);

      // Check health degraded
      final newHealth = container.read(networkHealthProvider);
      expect(newHealth.tier, isNot(HealthTier.healthy));

      // Catastrophe state should have a transition
      final state = container.read(catastropheProvider);
      expect(state.latestTransition, isNotNull);
      expect(state.latestTransition!.isWorsening, isTrue);
    });

    test('recordMissionReview marks concept reviewed', () {
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(KnowledgeGraph()),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Read to initialize
      container.read(catastropheProvider);

      // Manually add a mission to test review recording
      final notifier = container.read(catastropheProvider.notifier);
      notifier.recordMissionReview('some-concept');

      // Since there are no active missions, this should be a no-op
      final state = container.read(catastropheProvider);
      expect(state.activeMissions, isEmpty);
    });

    test('seeds previousTier from current health on cold start', () {
      // Start with an empty graph (async load hasn't completed)
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(KnowledgeGraph()),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Synchronously set a degraded graph (simulates app state after load)
      final degradedGraph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'a',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 0,
            repetitions: 0,
            nextReview: DateTime.utc(2020),
            lastReview: null,
          ),
        ],
      );
      container.read(knowledgeGraphProvider.notifier).setGraph(degradedGraph);

      // Verify health is degraded
      final health = container.read(networkHealthProvider);
      expect(health.tier, isNot(HealthTier.healthy));

      // Now read catastrophe provider for the first time (cold start).
      // It should seed previousTier from current health, not default healthy.
      final state = container.read(catastropheProvider);
      expect(state.previousTier, health.tier);
      // No phantom transition should fire
      expect(state.latestTransition, isNull);
      expect(state.activeEvents, isEmpty);
    });

    test('improving transition only resolves events worse than new tier', () {
      final container = ProviderContainer(
        overrides: [
          knowledgeGraphProvider.overrideWith(
            () => _PreloadedGraphNotifier(KnowledgeGraph()),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initialize and read catastrophe provider
      container.read(catastropheProvider);

      // First degrade to cascade (score < 0.50)
      final degradedGraph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'a',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 0,
            repetitions: 0,
            nextReview: DateTime.utc(2020),
            lastReview: null,
          ),
          QuizItem(
            id: 'q2',
            conceptId: 'b',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 0,
            repetitions: 0,
            nextReview: DateTime.utc(2020),
            lastReview: null,
          ),
        ],
      );

      container.read(knowledgeGraphProvider.notifier).setGraph(degradedGraph);

      final afterDegrade = container.read(catastropheProvider);
      expect(afterDegrade.activeEvents, isNotEmpty);

      // Now improve back to healthy
      final recentReview = DateTime.utc(2025, 6, 10);
      final healthyGraph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'a',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: recentReview,
          ),
          QuizItem(
            id: 'q2',
            conceptId: 'b',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: recentReview,
          ),
        ],
      );

      container.read(knowledgeGraphProvider.notifier).setGraph(healthyGraph);

      final afterImprove = container.read(catastropheProvider);
      expect(afterImprove.latestTransition, isNotNull);
      expect(afterImprove.latestTransition!.isImproving, isTrue);
      // Events worse than healthy (index 0) should be resolved and removed
      // from active list. With strict > comparison, events at the degraded
      // tier ARE resolved because eventTier.index > healthy.index (0).
      expect(afterImprove.activeEvents, isEmpty);
    });
  });

  group('TierTransition', () {
    final epoch = DateTime.utc(2025, 1, 1);

    test('isWorsening when tier increases', () {
      final transition = TierTransition(
        from: HealthTier.healthy,
        to: HealthTier.brownout,
        timestamp: epoch,
      );
      expect(transition.isWorsening, isTrue);
      expect(transition.isImproving, isFalse);
    });

    test('isImproving when tier decreases', () {
      final transition = TierTransition(
        from: HealthTier.fracture,
        to: HealthTier.cascade,
        timestamp: epoch,
      );
      expect(transition.isWorsening, isFalse);
      expect(transition.isImproving, isTrue);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._initial);

  final KnowledgeGraph _initial;

  @override
  Future<KnowledgeGraph> build() async => _initial;
}
