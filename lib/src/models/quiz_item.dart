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
  });

  /// Creates a new card with SM-2 defaults.
  factory QuizItem.newCard({
    required String id,
    required String conceptId,
    required String question,
    required String answer,
  }) {
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: 2.5,
      interval: 0,
      repetitions: 0,
      nextReview: DateTime.now().toUtc().toIso8601String(),
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
      nextReview: json['nextReview'] as String,
      lastReview: json['lastReview'] as String?,
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

  QuizItem withReview({
    required double easeFactor,
    required int interval,
    required int repetitions,
    required String nextReview,
  }) {
    return QuizItem(
      id: id,
      conceptId: conceptId,
      question: question,
      answer: answer,
      easeFactor: easeFactor,
      interval: interval,
      repetitions: repetitions,
      nextReview: nextReview,
      lastReview: DateTime.now().toUtc().toIso8601String(),
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
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QuizItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuizItem($id: $question)';
}
