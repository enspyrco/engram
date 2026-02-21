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
  int repetitions = 0,
  DateTime? lastReview,
  String? prerequisiteId,
  int prerequisiteRepetitions = 0,
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
      easeFactor: 2.5,
      interval: interval,
      repetitions: repetitions,
      nextReview: DateTime.utc(2099),
      lastReview: lastReview,
    ),
    if (prerequisiteId != null)
      QuizItem(
        id: 'q_prereq',
        conceptId: prerequisiteId,
        question: 'PQ?',
        answer: 'PA.',
        easeFactor: 2.5,
        interval: 0,
        repetitions: prerequisiteRepetitions,
        nextReview: DateTime.utc(2099),
        lastReview: null,
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
    test('locked when prerequisites not mastered', () {
      // prerequisiteRepetitions=0 means prereq is unmastered → dependent is locked
      final graph = graphWithQuizItems(
        conceptId: 'dep',
        prerequisiteId: 'prereq',
        prerequisiteRepetitions: 0,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('dep', graph, analyzer), MasteryState.locked);
    });

    test('due when unlocked with unreviewed items (repetitions==0)', () {
      final graph = graphWithQuizItems(repetitions: 0);
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.due);
    });

    test('learning when all reviewed but interval < 21', () {
      final graph = graphWithQuizItems(interval: 10, repetitions: 3);
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.learning);
    });

    test('mastered when all items interval >= 21 and recent review', () {
      final now = DateTime.utc(2025, 6, 15);
      final recentReview = DateTime.utc(2025, 6, 10);

      final graph = graphWithQuizItems(
        interval: 25,
        repetitions: 5,
        lastReview: recentReview,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.mastered,
      );
    });

    test('fading when mastered but lastReview > 30 days ago', () {
      final now = DateTime.utc(2025, 6, 15);
      // 45 days ago
      final oldReview = DateTime.utc(2025, 5, 1);

      final graph = graphWithQuizItems(
        interval: 25,
        repetitions: 5,
        lastReview: oldReview,
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.fading,
      );
    });
  });

  group('freshnessOf decay curve', () {
    final now = DateTime.utc(2025, 6, 15);

    KnowledgeGraph graphReviewedDaysAgo(int days) {
      final review = now.subtract(Duration(days: days));
      return graphWithQuizItems(
        interval: 25,
        repetitions: 5,
        lastReview: review,
      );
    }

    test('1.0 when just reviewed (0 days)', () {
      final graph = graphReviewedDaysAgo(0);
      expect(freshnessOf('c1', graph, now: now), closeTo(1.0, 0.001));
    });

    test(
      'linear decay: 0.825 at 15d, 0.65 at 30d, 0.475 at 45d, 0.3 at 60d',
      () {
        expect(
          freshnessOf('c1', graphReviewedDaysAgo(15), now: now),
          closeTo(0.825, 0.01),
        );
        expect(
          freshnessOf('c1', graphReviewedDaysAgo(30), now: now),
          closeTo(0.65, 0.01),
        );
        expect(
          freshnessOf('c1', graphReviewedDaysAgo(45), now: now),
          closeTo(0.475, 0.01),
        );
        expect(
          freshnessOf('c1', graphReviewedDaysAgo(60), now: now),
          closeTo(0.3, 0.01),
        );
      },
    );

    test('floors at 0.3 beyond 60 days', () {
      expect(
        freshnessOf('c1', graphReviewedDaysAgo(90), now: now),
        closeTo(0.3, 0.001),
      );
      expect(
        freshnessOf('c1', graphReviewedDaysAgo(365), now: now),
        closeTo(0.3, 0.001),
      );
    });

    test('1.0 when no lastReview', () {
      final graph = graphWithQuizItems(repetitions: 0, lastReview: null);
      expect(freshnessOf('c1', graph, now: now), 1.0);
    });

    test('decayMultiplier accelerates decay (2.0x at 30d = 0.3)', () {
      final graph = graphReviewedDaysAgo(30);

      final normal = freshnessOf('c1', graph, now: now);
      final doubled = freshnessOf('c1', graph, now: now, decayMultiplier: 2.0);

      expect(normal, closeTo(0.65, 0.01));
      // 30 days * 2.0 = 60 effective days → hits the 0.3 floor
      expect(doubled, closeTo(0.3, 0.01));
      expect(doubled, lessThan(normal));
    });
  });
}
