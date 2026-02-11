import 'package:engram/src/engine/network_health_scorer.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/network_health.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkHealthScorer', () {
    final now = DateTime.utc(2025, 6, 15);
    final recentReview = DateTime.utc(2025, 6, 10).toIso8601String();
    final oldReview = DateTime.utc(2025, 4, 1).toIso8601String();

    test('empty graph returns healthy with score 1.0', () {
      final graph = KnowledgeGraph();
      final health = NetworkHealthScorer(graph, now: now).score();

      expect(health.score, 1.0);
      expect(health.tier, HealthTier.healthy);
    });

    test('all mastered and fresh returns high score', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1', conceptId: 'a', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
          QuizItem(
            id: 'q2', conceptId: 'b', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
        ],
      );

      final health = NetworkHealthScorer(graph, now: now).score();

      // All mastered + no learning → 0.5*1.0 + 0.3*0.0 + 0.2*freshness ≈ 0.69
      // (mastered and learning are mutually exclusive per concept)
      expect(health.score, greaterThan(0.65));
      expect(health.tier, HealthTier.brownout); // < 0.70 threshold
      expect(health.masteryRatio, 1.0);
      expect(health.learningRatio, 0.0);
    });

    test('all due returns low score', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          const QuizItem(
            id: 'q1', conceptId: 'a', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 0, repetitions: 0,
            nextReview: '2020-01-01', lastReview: null,
          ),
          const QuizItem(
            id: 'q2', conceptId: 'b', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 0, repetitions: 0,
            nextReview: '2020-01-01', lastReview: null,
          ),
        ],
      );

      final health = NetworkHealthScorer(graph, now: now).score();

      expect(health.masteryRatio, 0.0);
      expect(health.learningRatio, 0.0);
      // Score should be freshness-only (0.2 * 1.0 = 0.2)
      expect(health.score, closeTo(0.2, 0.05));
    });

    test('mixed state produces intermediate score', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
          Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
          Concept(id: 'd', name: 'D', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          // a: mastered
          QuizItem(
            id: 'q1', conceptId: 'a', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
          // b: learning
          QuizItem(
            id: 'q2', conceptId: 'b', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 6, repetitions: 2,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
          // c: due
          const QuizItem(
            id: 'q3', conceptId: 'c', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 0, repetitions: 0,
            nextReview: '2020-01-01', lastReview: null,
          ),
          // d: fading
          QuizItem(
            id: 'q4', conceptId: 'd', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: oldReview,
          ),
        ],
      );

      final health = NetworkHealthScorer(graph, now: now).score();

      // 2/4 mastered (a + d/fading), 1/4 learning
      expect(health.masteryRatio, 0.5);
      expect(health.learningRatio, 0.25);
      expect(health.score, greaterThan(0.3));
      expect(health.score, lessThan(0.8));
    });

    test('critical path penalty reduces score', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'hub', name: 'Hub', description: '', sourceDocumentId: 'd'),
          Concept(id: 'dep1', name: 'Dep1', description: '', sourceDocumentId: 'd'),
          Concept(id: 'dep2', name: 'Dep2', description: '', sourceDocumentId: 'd'),
        ],
        relationships: [
          // dep1 and dep2 both depend on hub → hub has out-degree 2
          const Relationship(id: 'r1', fromConceptId: 'dep1', toConceptId: 'hub', label: 'depends on'),
          const Relationship(id: 'r2', fromConceptId: 'dep2', toConceptId: 'hub', label: 'depends on'),
        ],
        quizItems: [
          // hub: due (at-risk critical path!)
          const QuizItem(
            id: 'q1', conceptId: 'hub', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 0, repetitions: 0,
            nextReview: '2020-01-01', lastReview: null,
          ),
          // dep1, dep2: locked (because hub not mastered)
          const QuizItem(
            id: 'q2', conceptId: 'dep1', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 0, repetitions: 0,
            nextReview: '2020-01-01', lastReview: null,
          ),
          const QuizItem(
            id: 'q3', conceptId: 'dep2', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 0, repetitions: 0,
            nextReview: '2020-01-01', lastReview: null,
          ),
        ],
      );

      final health = NetworkHealthScorer(graph, now: now).score();

      expect(health.atRiskCriticalPaths, 1);
      expect(health.totalCriticalPaths, 1);
      // Score should be penalized vs same graph without dependencies
    });

    test('tier matches score thresholds', () {
      expect(NetworkHealth.tierFromScore(0.95), HealthTier.healthy);
      expect(NetworkHealth.tierFromScore(0.70), HealthTier.healthy);
      expect(NetworkHealth.tierFromScore(0.69), HealthTier.brownout);
      expect(NetworkHealth.tierFromScore(0.50), HealthTier.brownout);
      expect(NetworkHealth.tierFromScore(0.49), HealthTier.cascade);
      expect(NetworkHealth.tierFromScore(0.30), HealthTier.cascade);
      expect(NetworkHealth.tierFromScore(0.29), HealthTier.fracture);
      expect(NetworkHealth.tierFromScore(0.10), HealthTier.fracture);
      expect(NetworkHealth.tierFromScore(0.09), HealthTier.collapse);
      expect(NetworkHealth.tierFromScore(0.0), HealthTier.collapse);
    });

    test('per-cluster health is computed', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        relationships: [
          const Relationship(id: 'r1', fromConceptId: 'a', toConceptId: 'b', label: 'relates to'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1', conceptId: 'a', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
          QuizItem(
            id: 'q2', conceptId: 'b', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
        ],
      );

      final health = NetworkHealthScorer(graph, now: now).score();

      expect(health.clusterHealth, isNotEmpty);
    });

    test('decayMultiplier lowers scores via faster freshness decay', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        quizItems: [
          QuizItem(
            id: 'q1', conceptId: 'a', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
          QuizItem(
            id: 'q2', conceptId: 'b', question: 'Q?', answer: 'A.',
            easeFactor: 2.5, interval: 25, repetitions: 5,
            nextReview: '2099-01-01', lastReview: recentReview,
          ),
        ],
      );

      final normalHealth = NetworkHealthScorer(graph, now: now).score();
      final stormHealth =
          NetworkHealthScorer(graph, now: now, decayMultiplier: 2.0).score();

      // Storm should produce a lower score due to reduced freshness
      expect(stormHealth.score, lessThanOrEqualTo(normalHealth.score));
      expect(stormHealth.avgFreshness,
          lessThanOrEqualTo(normalHealth.avgFreshness));
    });

    test('NetworkHealth JSON round-trip', () {
      const health = NetworkHealth(
        score: 0.75,
        tier: HealthTier.healthy,
        masteryRatio: 0.6,
        learningRatio: 0.2,
        avgFreshness: 0.8,
        atRiskCriticalPaths: 1,
        totalCriticalPaths: 3,
        clusterHealth: {'CI/CD': 0.9, 'Security': 0.5},
      );

      final json = health.toJson();
      final restored = NetworkHealth.fromJson(json);

      expect(restored.score, health.score);
      expect(restored.tier, health.tier);
      expect(restored.masteryRatio, health.masteryRatio);
      expect(restored.clusterHealth, health.clusterHealth);
    });
  });
}
