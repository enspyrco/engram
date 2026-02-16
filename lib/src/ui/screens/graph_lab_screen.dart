import 'package:flutter/material.dart';

import '../../models/concept.dart';
import '../../models/knowledge_graph.dart';
import '../../models/quiz_item.dart';
import '../../models/relationship.dart';
import '../graph/force_directed_graph_widget.dart';

/// Test bed for the force-directed graph animation.
///
/// Displays a small hardcoded graph with nodes in every mastery state
/// (locked, due, learning, mastered, fading) so layout and rendering
/// can be verified visually without needing real extraction data.
class GraphLabScreen extends StatelessWidget {
  const GraphLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Graph Lab')),
      body: ForceDirectedGraphWidget(graph: _testGraph),
    );
  }
}

// ---------------------------------------------------------------------------
// Test data — 6 concepts, 5 relationships, 6 quiz items.
//
// Topology:
//   A (mastered)  ←─depends on─  B (learning)
//   A  ──relates to──▶  C (due)
//   C  ←─depends on─  D (locked — C has reps=0 so D can't unlock)
//   A  ←─relates to─  E (fading)
//   E  ←─relates to─  F (mastered)
// ---------------------------------------------------------------------------

final _now = DateTime.now().toUtc();

final _testGraph = KnowledgeGraph(
  concepts: [
    Concept(
      id: 'a',
      name: 'Spaced Repetition',
      description: 'Reviewing material at increasing intervals to combat forgetting',
      sourceDocumentId: 'doc-lab',
    ),
    Concept(
      id: 'b',
      name: 'Leitner System',
      description: 'Card-box system that sorts flashcards by mastery level',
      sourceDocumentId: 'doc-lab',
    ),
    Concept(
      id: 'c',
      name: 'Active Recall',
      description: 'Actively retrieving information from memory rather than re-reading',
      sourceDocumentId: 'doc-lab',
    ),
    Concept(
      id: 'd',
      name: 'FSRS Algorithm',
      description: 'Free Spaced Repetition Scheduler — modern successor to SM-2',
      sourceDocumentId: 'doc-lab',
    ),
    Concept(
      id: 'e',
      name: 'Forgetting Curve',
      description: 'Ebbinghaus curve showing exponential memory decay over time',
      sourceDocumentId: 'doc-lab',
    ),
    Concept(
      id: 'f',
      name: 'Memory Palace',
      description: 'Method of loci — placing items in imagined spatial locations',
      sourceDocumentId: 'doc-lab',
    ),
  ],
  relationships: [
    // Dependency edges (affect unlock status)
    Relationship(id: 'r1', fromConceptId: 'b', toConceptId: 'a', label: 'depends on'),
    Relationship(id: 'r2', fromConceptId: 'd', toConceptId: 'c', label: 'depends on'),
    // Non-dependency edges (visual connections only)
    Relationship(id: 'r3', fromConceptId: 'c', toConceptId: 'a', label: 'relates to'),
    Relationship(id: 'r4', fromConceptId: 'e', toConceptId: 'a', label: 'relates to'),
    Relationship(id: 'r5', fromConceptId: 'f', toConceptId: 'e', label: 'relates to'),
  ],
  quizItems: [
    // A → mastered: interval ≥ 21, recent review
    QuizItem(
      id: 'q1', conceptId: 'a',
      question: 'What is spaced repetition?',
      answer: 'Reviewing at increasing intervals to combat forgetting',
      easeFactor: 2.5, interval: 30, repetitions: 5,
      nextReview: _now.add(const Duration(days: 30)).toIso8601String(),
      lastReview: _now.subtract(const Duration(days: 2)).toIso8601String(),
    ),
    // B → learning: repetitions ≥ 1 but interval < 21
    QuizItem(
      id: 'q2', conceptId: 'b',
      question: 'What is the Leitner system?',
      answer: 'A card-box sorting system for spaced review',
      easeFactor: 2.5, interval: 7, repetitions: 2,
      nextReview: _now.add(const Duration(days: 7)).toIso8601String(),
      lastReview: _now.subtract(const Duration(days: 1)).toIso8601String(),
    ),
    // C → due: never reviewed (repetitions = 0)
    QuizItem(
      id: 'q3', conceptId: 'c',
      question: 'What is active recall?',
      answer: 'Actively retrieving information from memory',
      easeFactor: 2.5, interval: 0, repetitions: 0,
      nextReview: _now.toIso8601String(),
      lastReview: null,
    ),
    // D → locked: C is its prerequisite and C is not mastered
    QuizItem(
      id: 'q4', conceptId: 'd',
      question: 'What is FSRS?',
      answer: 'Free Spaced Repetition Scheduler',
      easeFactor: 2.5, interval: 0, repetitions: 0,
      nextReview: _now.toIso8601String(),
      lastReview: null,
    ),
    // E → fading: mastered (interval ≥ 21) but lastReview > 30 days ago
    QuizItem(
      id: 'q5', conceptId: 'e',
      question: 'What is the forgetting curve?',
      answer: 'Exponential memory decay over time (Ebbinghaus)',
      easeFactor: 2.5, interval: 30, repetitions: 3,
      nextReview: _now.toIso8601String(),
      lastReview: _now.subtract(const Duration(days: 45)).toIso8601String(),
    ),
    // F → mastered: interval ≥ 21, recent review
    QuizItem(
      id: 'q6', conceptId: 'f',
      question: 'What is a memory palace?',
      answer: 'Method of loci — spatial memory technique',
      easeFactor: 2.5, interval: 25, repetitions: 4,
      nextReview: _now.add(const Duration(days: 25)).toIso8601String(),
      lastReview: _now.subtract(const Duration(days: 3)).toIso8601String(),
    ),
  ],
);
