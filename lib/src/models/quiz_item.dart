import 'package:meta/meta.dart';

import '../engine/fsrs_engine.dart';

/// Days of FSRS stability required to consider a card mastered enough to
/// unlock dependent concepts.
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

  /// Creates a new card with FSRS state bootstrapped.
  ///
  /// [predictedDifficulty] seeds the FSRS difficulty parameter (1.0-10.0).
  /// Defaults to 5.0 (neutral midpoint) when null.
  factory QuizItem.newCard({
    required String id,
    required String conceptId,
    required String question,
    required String answer,
    double? predictedDifficulty,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();

    final fsrs = initializeFsrsCard(
      predictedDifficulty: predictedDifficulty ?? 5.0,
      now: currentTime,
    );
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: 2.5, // legacy
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

  /// Deserializes a card from JSON, auto-migrating legacy SM-2 cards to FSRS.
  ///
  /// Cards missing `stability` or `fsrsState` are bootstrapped via
  /// [initializeFsrsCard] using the existing `difficulty` (or 5.0 default).
  /// Existing `nextReview`/`interval`/`lastReview` from SM-2 are preserved.
  factory QuizItem.fromJson(Map<String, dynamic> json) {
    final difficulty = (json['difficulty'] as num?)?.toDouble();
    final stability = (json['stability'] as num?)?.toDouble();
    final fsrsState = json['fsrsState'] as int?;
    final lapses = json['lapses'] as int?;

    // Auto-migrate: bootstrap FSRS state for legacy cards.
    if (stability == null || fsrsState == null) {
      final fsrs = initializeFsrsCard(
        predictedDifficulty: difficulty ?? 5.0,
      );
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
        difficulty: fsrs.difficulty,
        stability: fsrs.stability,
        fsrsState: fsrs.fsrsState,
        lapses: fsrs.lapses,
      );
    }

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
      difficulty: difficulty,
      stability: stability,
      fsrsState: fsrsState,
      lapses: lapses,
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

  /// FSRS difficulty (1.0-10.0). Seeded by Claude's predicted difficulty at
  /// extraction time; auto-migrated to 5.0 for legacy cards.
  final double? difficulty;

  /// FSRS stability in days — the interval at which recall = 90%.
  final double? stability;

  /// FSRS state: 1=learning, 2=review, 3=relearning.
  final int? fsrsState;

  /// Number of times the card lapsed (review → relearning).
  final int? lapses;

  /// Whether this card has full FSRS state.
  ///
  /// After Phase 3 migration, all cards are FSRS. This getter is retained
  /// for defensive checks during the transition.
  bool get isFsrs => difficulty != null && stability != null && fsrsState != null;

  /// Whether this card is mastered enough to unlock dependent concepts.
  ///
  /// Uses FSRS stability >= [masteryUnlockDays] (memory strength).
  bool get isMasteredForUnlock => stability != null && stability! >= masteryUnlockDays;

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
  /// the sender's FSRS scheduling data. Keeps `difficulty` since it's
  /// Claude's content prediction, not learner state.
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
