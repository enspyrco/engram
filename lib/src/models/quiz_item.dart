import 'package:meta/meta.dart';

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
  factory QuizItem.newCard({
    required String id,
    required String conceptId,
    required String question,
    required String answer,
    double? predictedDifficulty,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: 2.5,
      interval: 0,
      repetitions: 0,
      nextReview: currentTime.toIso8601String(),
      lastReview: null,
      difficulty: predictedDifficulty?.clamp(1.0, 10.0),
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
      nextReview: json['nextReview'] as String,
      lastReview: json['lastReview'] as String?,
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
  final String nextReview;
  final String? lastReview;

  /// FSRS difficulty (1.0-10.0). Null for legacy SM-2-only cards.
  /// Seeded by Claude's predicted difficulty at extraction time.
  final double? difficulty;

  /// FSRS stability (days). Null for legacy SM-2-only cards.
  final double? stability;

  /// FSRS state: 1=learning, 2=review, 3=relearning. Null for legacy cards.
  final int? fsrsState;

  /// Number of times the card lapsed (review → relearning). Null for legacy cards.
  final int? lapses;

  QuizItem withReview({
    required double easeFactor,
    required int interval,
    required int repetitions,
    required String nextReview,
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
      lastReview: currentTime.toIso8601String(),
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
    required String nextReview,
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
      lastReview: currentTime.toIso8601String(),
      difficulty: difficulty,
      stability: stability,
      fsrsState: fsrsState,
      lapses: lapses,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conceptId': conceptId,
        'question': question,
        'answer': answer,
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReview': nextReview,
        'lastReview': lastReview,
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
