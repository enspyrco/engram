import 'package:engram/src/models/quiz_item.dart';

/// Creates a test [QuizItem] with FSRS state and sensible defaults.
///
/// Use named parameters to override specific fields. All cards are FSRS-ready.
QuizItem testQuizItem({
  String id = 'q1',
  String conceptId = 'c1',
  String question = 'What is X?',
  String answer = 'X is Y',
  double easeFactor = 2.5,
  int interval = 0,
  int repetitions = 0,
  DateTime? nextReview,
  DateTime? lastReview,
  double difficulty = 5.0,
  double stability = 3.26,
  int fsrsState = 1,
  int lapses = 0,
}) {
  return QuizItem(
    id: id,
    conceptId: conceptId,
    question: question,
    answer: answer,
    easeFactor: easeFactor,
    interval: interval,
    repetitions: repetitions,
    nextReview: nextReview ?? DateTime.utc(2026, 2, 20),
    lastReview: lastReview,
    difficulty: difficulty,
    stability: stability,
    fsrsState: fsrsState,
    lapses: lapses,
  );
}

/// Creates a reviewed [QuizItem] in FSRS review state (mastered).
///
/// Useful for tests that need a mastered card with history.
QuizItem masteredQuizItem({
  String id = 'q1',
  String conceptId = 'c1',
  String question = 'What is X?',
  String answer = 'X is Y',
  DateTime? lastReview,
}) {
  return QuizItem(
    id: id,
    conceptId: conceptId,
    question: question,
    answer: answer,
    easeFactor: 2.5,
    interval: 25,
    repetitions: 3,
    nextReview: DateTime.utc(2026, 3, 20),
    lastReview: lastReview ?? DateTime.utc(2026, 2, 20),
    difficulty: 5.0,
    stability: 25.0,
    fsrsState: 2, // review state
    lapses: 0,
  );
}
