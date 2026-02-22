import 'package:meta/meta.dart';

import '../engine/fsrs_engine.dart';

/// Days of stability (FSRS) or interval (SM-2) required to consider a card
/// mastered enough to unlock dependent concepts.
const masteryUnlockDays = 21;

@immutable
class QuizItem {
  const QuizItem({
    required this.id,
    required this.conceptId,
    required this.question,
    required this.answer,
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
    required this.lastReview,
    this.difficulty,
    this.stability,
    this.fsrsState,
    this.lapses,
  });

  /// Creates a new card with SM-2 defaults.
  ///
  /// When [predictedDifficulty] is provided, FSRS state is bootstrapped
  /// via [initializeFsrsCard] so the card is immediately ready for
  /// [reviewFsrs] on first review.
  factory QuizItem.newCard({
    required String id,
    required String conceptId,
    required String question,
    required String answer,
    double? predictedDifficulty,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();

    // Bootstrap FSRS state when Claude predicts difficulty at extraction time.
    if (predictedDifficulty != null) {
      final fsrs = initializeFsrsCard(
        predictedDifficulty: predictedDifficulty,
        now: currentTime,
      );
      return QuizItem(
        id: id,
        conceptId: conceptId,
        question: question,
        answer: answer,
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        nextReview: currentTime,
        lastReview: null,
        difficulty: fsrs.difficulty,
        stability: fsrs.stability,
        fsrsState: fsrs.fsrsState,
        lapses: fsrs.lapses,
      );
    }

    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: 2.5,
      interval: 0,
      repetitions: 0,
      nextReview: currentTime,
      lastReview: null,
    );
  }

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      id: json['id'] as String,
      conceptId: json['conceptId'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      easeFactor: (json['easeFactor'] as num).toDouble(),
      interval: json['interval'] as int,
      repetitions: json['repetitions'] as int,
      nextReview: DateTime.parse(json['nextReview'] as String),
      lastReview:
          json['lastReview'] != null
              ? DateTime.parse(json['lastReview'] as String)
              : null,
      difficulty: (json['difficulty'] as num?)?.toDouble(),
      stability: (json['stability'] as num?)?.toDouble(),
      fsrsState: json['fsrsState'] as int?,
      lapses: json['lapses'] as int?,
    );
  }

  final String id;
  final String conceptId;
  final String question;
  final String answer;
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime nextReview;
  final DateTime? lastReview;

  /// FSRS difficulty (1.0-10.0). Null for legacy SM-2-only cards.
  /// Seeded by Claude's predicted difficulty at extraction time.
  final double? difficulty;

  /// FSRS stability (days). Null for legacy SM-2-only cards.
  final double? stability;

  /// FSRS state: 1=learning, 2=review, 3=relearning. Null for legacy cards.
  final int? fsrsState;

  /// Number of times the card lapsed (review → relearning). Null for legacy cards.
  final int? lapses;

  /// Whether this card has full FSRS state and should use `reviewFsrs()`.
  ///
  /// Cards with only `difficulty` (Phase 1 legacy) but no `stability`/`fsrsState`
  /// return false and continue using SM-2 until re-extracted.
  bool get isFsrs => difficulty != null && stability != null && fsrsState != null;

  /// Whether this card is mastered enough to unlock dependent concepts.
  ///
  /// FSRS cards use stability >= [masteryUnlockDays] (memory strength).
  /// SM-2 cards use interval >= [masteryUnlockDays] (scheduled gap).
  /// Centralizes the check used in relay completion, filtered stats, and
  /// graph analysis.
  bool get isMasteredForUnlock =>
      isFsrs ? stability! >= masteryUnlockDays : interval >= masteryUnlockDays;

  QuizItem withReview({
    required double easeFactor,
    required int interval,
    required int repetitions,
    required DateTime nextReview,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: easeFactor,
      interval: interval,
      repetitions: repetitions,
      nextReview: nextReview,
      lastReview: currentTime,
      difficulty: difficulty,
      stability: stability,
      fsrsState: fsrsState,
      lapses: lapses,
    );
  }

  QuizItem withFsrsReview({
    required double difficulty,
    required double stability,
    required int fsrsState,
    required int lapses,
    required int interval,
    required DateTime nextReview,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: easeFactor,
      interval: interval,
      repetitions: repetitions,
      nextReview: nextReview,
      lastReview: currentTime,
      difficulty: difficulty,
      stability: stability,
      fsrsState: fsrsState,
      lapses: lapses,
    );
  }

  /// Returns only content fields, omitting scheduling state.
  ///
  /// Used for challenge snapshots where the recipient shouldn't see
  /// the sender's SM-2/FSRS scheduling data.
  Map<String, dynamic> toContentSnapshot() => {
    'id': id,
    'conceptId': conceptId,
    'question': question,
    'answer': answer,
    if (difficulty != null) 'difficulty': difficulty,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'conceptId': conceptId,
    'question': question,
    'answer': answer,
    'easeFactor': easeFactor,
    'interval': interval,
    'repetitions': repetitions,
    'nextReview': nextReview.toIso8601String(),
    'lastReview': lastReview?.toIso8601String(),
    if (difficulty != null) 'difficulty': difficulty,
    if (stability != null) 'stability': stability,
    if (fsrsState != null) 'fsrsState': fsrsState,
    if (lapses != null) 'lapses': lapses,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QuizItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuizItem($id: $question)';
}
