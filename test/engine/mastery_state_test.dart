import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/engine/mastery_state.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  group('masteryStateOf', () {
    test('locked when prerequisites not mastered', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'prereq',
            name: 'P',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
          Concept(
            id: 'dep',
            name: 'D',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'dep',
            toConceptId: 'prereq',
            label: 'depends on',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'prereq',
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
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('dep', graph, analyzer), MasteryState.locked);
    });

    test('due when unlocked but no reviews', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
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
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.due);
    });

    test('learning when FSRS retrievability between 0.5 and 0.85', () {
      // Stability = 5 days, last review 10 days ago → R between 0.5 and 0.85
      final now = DateTime.utc(2025, 6, 15);
      final lastReview = DateTime.utc(2025, 6, 5); // 10 days ago
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 5,
            repetitions: 3,
            nextReview: DateTime.utc(2025, 6, 10),
            lastReview: lastReview,
            difficulty: 5.0,
            stability: 5.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      // Verify the retrievability is actually in the learning range.
      final r = fsrsRetrievability(
        stability: 5.0,
        fsrsState: 2,
        lastReview: lastReview,
        now: now,
      );
      expect(r, greaterThanOrEqualTo(fsrsDueThreshold));
      expect(r, lessThan(fsrsMasteredThreshold));

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.learning,
      );
    });

    test('mastered when FSRS retrievability >= 0.85 and recently reviewed', () {
      // Stability = 100 days, last review 5 days ago → R close to 1.0
      final now = DateTime.utc(2025, 6, 15);
      final recentReview = DateTime.utc(2025, 6, 10); // 5 days ago
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 100,
            repetitions: 5,
            nextReview: DateTime.utc(2025, 9, 23),
            lastReview: recentReview,
            difficulty: 5.0,
            stability: 100.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      // Verify retrievability is in the mastered range.
      final r = fsrsRetrievability(
        stability: 100.0,
        fsrsState: 2,
        lastReview: recentReview,
        now: now,
      );
      expect(r, greaterThanOrEqualTo(fsrsMasteredThreshold));

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.mastered,
      );
    });

    test('due when FSRS card has no lastReview (even with high interval)', () {
      // With FSRS-only scheduling, cards without lastReview are always due
      // regardless of interval or repetitions.
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: null,
            difficulty: 5.0,
            stability: 50.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.due);
    });

    test('fading when FSRS mastered but lastReview > 30 days ago', () {
      // Stability = 1000 days (very stable), last review 45 days ago → R still
      // high enough for mastered, but fading threshold triggers.
      final now = DateTime.utc(2025, 6, 15);
      final oldReview = DateTime.utc(2025, 5, 1); // 45 days ago
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 1000,
            repetitions: 10,
            nextReview: DateTime.utc(2028),
            lastReview: oldReview,
            difficulty: 3.0,
            stability: 1000.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      // Verify R is still mastered-level despite 45 days elapsed.
      final r = fsrsRetrievability(
        stability: 1000.0,
        fsrsState: 2,
        lastReview: oldReview,
        now: now,
      );
      expect(r, greaterThanOrEqualTo(fsrsMasteredThreshold));

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.fading,
      );
    });

    test('mastered when no quiz items (informational node)', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.mastered);
    });
  });

  group('masteryStateOf (FSRS)', () {
    test('due when FSRS card has no lastReview', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 0,
            repetitions: 0,
            nextReview: DateTime.utc(2020),
            lastReview: null,
            difficulty: 5.0,
            stability: 3.26,
            fsrsState: 1,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(masteryStateOf('c1', graph, analyzer), MasteryState.due);
    });

    test('due when FSRS retrievability < 0.5', () {
      // Stability = 1 day, last review 100 days ago → R ≈ 0.43
      final now = DateTime.utc(2025, 6, 15);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 1,
            repetitions: 1,
            nextReview: DateTime.utc(2025, 3, 8),
            lastReview: DateTime.utc(2025, 3, 7), // 100 days ago
            difficulty: 8.0,
            stability: 1.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.due,
      );
    });

    test('mastered when FSRS retrievability >= 0.85', () {
      // Stability = 100 days, last review today → R close to 1.0
      final now = DateTime.utc(2025, 6, 15);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 100,
            repetitions: 5,
            nextReview: DateTime.utc(2025, 9, 23),
            lastReview: now,
            difficulty: 5.0,
            stability: 100.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.mastered,
      );
    });

    test('learning when FSRS retrievability between 0.5 and 0.85', () {
      // Stability = 5 days, last review 10 days ago → R ≈ 0.84
      final now = DateTime.utc(2025, 6, 15);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 5,
            repetitions: 3,
            nextReview: DateTime.utc(2025, 6, 10),
            lastReview: DateTime.utc(2025, 6, 5), // 10 days ago
            difficulty: 5.0,
            stability: 5.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.learning,
      );
    });

    test('fading when FSRS mastered but old lastReview', () {
      // Stability = 1000 days (very stable), last review 45 days ago → R still
      // high but fading threshold triggers
      final now = DateTime.utc(2025, 6, 15);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 1000,
            repetitions: 10,
            nextReview: DateTime.utc(2028),
            lastReview: DateTime.utc(2025, 5, 1), // 45 days ago
            difficulty: 3.0,
            stability: 1000.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );
      final analyzer = GraphAnalyzer(graph);

      expect(
        masteryStateOf('c1', graph, analyzer, now: now),
        MasteryState.fading,
      );
    });
  });

  group('freshnessOf', () {
    test('returns 1.0 for just reviewed (0 days)', () {
      final now = DateTime.utc(2025, 6, 15);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: now,
            difficulty: 5.0,
            stability: 25.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );

      expect(freshnessOf('c1', graph, now: now), closeTo(1.0, 0.01));
    });

    test('returns FSRS retrievability for 30 days ago', () {
      final now = DateTime.utc(2025, 6, 15);
      final thirtyDaysAgo = DateTime.utc(2025, 5, 16);
      const stability = 25.0;
      const fsrsState = 2;
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: thirtyDaysAgo,
            difficulty: 5.0,
            stability: stability,
            fsrsState: fsrsState,
            lapses: 0,
          ),
        ],
      );

      final expectedR = fsrsRetrievability(
        stability: stability,
        fsrsState: fsrsState,
        lastReview: thirtyDaysAgo,
        now: now,
      );

      expect(freshnessOf('c1', graph, now: now), closeTo(expectedR, 0.001));
    });

    test('returns FSRS retrievability for 60+ days ago', () {
      final now = DateTime.utc(2025, 6, 15);
      final sixtyDaysAgo = DateTime.utc(2025, 4, 16);
      // Use very low stability so 60 elapsed days produces significant decay.
      const stability = 1.0;
      const fsrsState = 2;
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 1,
            repetitions: 1,
            nextReview: DateTime.utc(2025, 4, 17),
            lastReview: sixtyDaysAgo,
            difficulty: 5.0,
            stability: stability,
            fsrsState: fsrsState,
            lapses: 0,
          ),
        ],
      );

      final expectedR = fsrsRetrievability(
        stability: stability,
        fsrsState: fsrsState,
        lastReview: sixtyDaysAgo,
        now: now,
      );

      // With FSRS, freshness equals retrievability — 60 days with S=1 gives
      // significant decay, well below the 30-days-ago higher-stability case.
      expect(freshnessOf('c1', graph, now: now), closeTo(expectedR, 0.001));
      expect(expectedR, lessThan(0.5)); // 60 days with S=1 → heavy decay
    });

    test('returns 1.0 when no lastReview', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
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

      expect(freshnessOf('c1', graph), 1.0);
    });

    test('decayMultiplier has no effect on FSRS freshness', () {
      // decayMultiplier is retained for API compatibility but does NOT affect
      // FSRS retrievability — storm decay is handled via desired_retention.
      final now = DateTime.utc(2025, 6, 15);
      final thirtyDaysAgo = DateTime.utc(2025, 5, 16);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: thirtyDaysAgo,
            difficulty: 5.0,
            stability: 25.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );

      final normal = freshnessOf('c1', graph, now: now);
      final doubled = freshnessOf('c1', graph, now: now, decayMultiplier: 2.0);

      // Both should be identical — decayMultiplier is a no-op for FSRS.
      expect(normal, doubled);
    });

    test('decayMultiplier 1.0 is default behavior', () {
      final now = DateTime.utc(2025, 6, 15);
      final review = DateTime.utc(2025, 5, 16);
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C',
            description: 'D',
            sourceDocumentId: 'doc1',
          ),
        ],
        quizItems: [
          QuizItem(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
            easeFactor: 2.5,
            interval: 25,
            repetitions: 5,
            nextReview: DateTime.utc(2099),
            lastReview: review,
            difficulty: 5.0,
            stability: 25.0,
            fsrsState: 2,
            lapses: 0,
          ),
        ],
      );

      final defaultVal = freshnessOf('c1', graph, now: now);
      final explicit = freshnessOf('c1', graph, now: now, decayMultiplier: 1.0);

      expect(defaultVal, explicit);
    });
  });

  test('masteryColors has all five states', () {
    expect(masteryColors, hasLength(5));
    expect(masteryColors[MasteryState.locked], Colors.grey);
    expect(masteryColors[MasteryState.due], Colors.red);
    expect(masteryColors[MasteryState.learning], Colors.amber);
    expect(masteryColors[MasteryState.mastered], Colors.green);
    expect(masteryColors[MasteryState.fading], const Color(0xFF81C784));
  });
}
