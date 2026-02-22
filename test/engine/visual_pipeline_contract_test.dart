import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/engine/mastery_state.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

// ── Inline helpers ──────────────────────────────────────────────────────

/// Build a graph with a single concept and quiz item for mastery/freshness tests.
KnowledgeGraph graphWithQuizItems({
  String conceptId = 'c1',
  int interval = 0,
  DateTime? lastReview,
  String? prerequisiteId,
  int prerequisiteFsrsState = 1,
  double? difficulty,
  double? stability,
  int? fsrsState,
  int? lapses,
}) {
  final concepts = [
    Concept(
      id: conceptId,
      name: 'Test',
      description: 'D',
      sourceDocumentId: 'doc1',
    ),
    if (prerequisiteId != null)
      Concept(
        id: prerequisiteId,
        name: 'Prereq',
        description: 'D',
        sourceDocumentId: 'doc1',
      ),
  ];
  final relationships = [
    if (prerequisiteId != null)
      Relationship(
        id: 'r1',
        fromConceptId: conceptId,
        toConceptId: prerequisiteId,
        label: 'depends on',
      ),
  ];
  final quizItems = [
    QuizItem(
      id: 'q1',
      conceptId: conceptId,
      question: 'Q?',
      answer: 'A.',
      interval: interval,
      nextReview: DateTime.utc(2099),
      lastReview: lastReview,
      difficulty: difficulty,
      stability: stability,
      fsrsState: fsrsState,
      lapses: lapses,
    ),
    if (prerequisiteId != null)
      QuizItem(
        id: 'q_prereq',
        conceptId: prerequisiteId,
        question: 'PQ?',
        answer: 'PA.',
        interval: 0,
        nextReview: DateTime.utc(2099),
        lastReview: null,
        fsrsState: prerequisiteFsrsState,
      ),
  ];

  return KnowledgeGraph(
    concepts: concepts,
    relationships: relationships,
    quizItems: quizItems,
  );
}

void main() {
  group('MasteryState completeness', () {
    test('has exactly five values', () {
      expect(MasteryState.values, hasLength(5));
      expect(
        MasteryState.values,
        containsAll([
          MasteryState.locked,
          MasteryState.due,
          MasteryState.learning,
          MasteryState.mastered,
          MasteryState.fading,
        ]),
      );
    });

    test('masteryColors maps every state', () {
      for (final state in MasteryState.values) {
        expect(masteryColors, contains(state));
      }
      expect(masteryColors, hasLength(5));
    });

    test('canonical colors', () {
      expect(masteryColors[MasteryState.locked], Colors.grey);
      expect(masteryColors[MasteryState.due], Colors.red);
      expect(masteryColors[MasteryState.learning], Colors.amber);
      expect(masteryColors[MasteryState.mastered], Colors.green);
      expect(masteryColors[MasteryState.fading], const Color(0xFF81C784));
    });
  });

  group('masteryStateOf state machine', () {
    test('locked when prerequisites not graduated', () {
      // prerequisiteFsrsState=1 means prereq is in learning → dependent is locked
      final graph = graphWithQuizItems(
        conceptId: 'dep',
        prerequisiteId: 'prereq',
        prerequisiteFsrsState: 1,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('dep', graph, analyzer), MasteryState.locked);
    });

    test('due when unlocked with unreviewed items', () {
      final graph = graphWithQuizItems();
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.due);
    });

    test('learning when FSRS retrievability between 0.5 and 0.85', () {
      // stability=5.0, reviewed 30 days ago → R ≈ 0.72 (between due and mastered)
      final now = DateTime.utc(2025, 6, 15);
      final review = now.subtract(const Duration(days: 30));
      final graph = graphWithQuizItems(
        lastReview: review,
        difficulty: 5.0,
        stability: 5.0,
        fsrsState: 2,
        lapses: 0,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.learning,
      );
    });

    test('mastered when FSRS retrievability >= 0.85', () {
      final now = DateTime.utc(2025, 6, 15);
      // stability=30.0, reviewed 1 day ago → R ≈ 0.996 (well above 0.85)
      final recentReview = DateTime.utc(2025, 6, 14);

      final graph = graphWithQuizItems(
        lastReview: recentReview,
        difficulty: 5.0,
        stability: 30.0,
        fsrsState: 2,
        lapses: 0,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.mastered,
      );
    });

    test('fading when FSRS retrievability >= 0.85 but lastReview > 30 days ago',
        () {
      final now = DateTime.utc(2025, 6, 15);
      // 45 days ago — need very high stability so R stays >= 0.85 despite age
      // stability=500.0, reviewed 45 days ago → R ≈ 0.99 (still mastered)
      // but lastReview > 30 days triggers fading
      final oldReview = DateTime.utc(2025, 5, 1);

      final graph = graphWithQuizItems(
        lastReview: oldReview,
        difficulty: 5.0,
        stability: 500.0,
        fsrsState: 2,
        lapses: 0,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.fading,
      );
    });
  });

  group('freshnessOf FSRS retrievability', () {
    final now = DateTime.utc(2025, 6, 15);

    /// Build a graph with FSRS items reviewed [days] ago.
    /// Uses stability=20.0 for predictable retrievability values.
    KnowledgeGraph graphReviewedDaysAgo(int days, {double stability = 20.0}) {
      final review = now.subtract(Duration(days: days));
      return graphWithQuizItems(
        lastReview: review,
        difficulty: 5.0,
        stability: stability,
        fsrsState: 2,
        lapses: 0,
      );
    }

    test('1.0 when just reviewed (0 days)', () {
      final graph = graphReviewedDaysAgo(0);
      expect(freshnessOf('c1', graph, now: now), closeTo(1.0, 0.001));
    });

    test('FSRS power-law decay: decreases with elapsed time', () {
      // With stability=20.0, retrievability decreases as time elapses.
      // Verify the monotonic decrease at increasing intervals.
      final r5 = freshnessOf('c1', graphReviewedDaysAgo(5), now: now);
      final r15 = freshnessOf('c1', graphReviewedDaysAgo(15), now: now);
      final r30 = freshnessOf('c1', graphReviewedDaysAgo(30), now: now);
      final r60 = freshnessOf('c1', graphReviewedDaysAgo(60), now: now);

      // All should be between 0 and 1
      for (final r in [r5, r15, r30, r60]) {
        expect(r, greaterThan(0.0));
        expect(r, lessThanOrEqualTo(1.0));
      }

      // Strictly decreasing
      expect(r5, greaterThan(r15));
      expect(r15, greaterThan(r30));
      expect(r30, greaterThan(r60));
    });

    test('low freshness for very old reviews with low stability', () {
      // FSRS power-law decay is slow; even S=1.0, 365d → R ≈ 0.33.
      // Verify it drops well below 0.5 for old, low-stability items.
      final r365 = freshnessOf(
        'c1',
        graphReviewedDaysAgo(365, stability: 1.0),
        now: now,
      );
      expect(r365, lessThan(0.5));
      expect(r365, greaterThan(0.0));
    });

    test('1.0 when no lastReview (non-FSRS items)', () {
      final graph = graphWithQuizItems(lastReview: null);
      expect(freshnessOf('c1', graph, now: now), 1.0);
    });
  });
}
