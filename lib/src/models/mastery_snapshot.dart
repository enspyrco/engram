import 'package:meta/meta.dart';

/// Lightweight mastery summary shared with friends.
@immutable
class MasterySnapshot {
  const MasterySnapshot({
    this.totalConcepts = 0,
    this.mastered = 0,
    this.learning = 0,
    this.newCount = 0,
    this.streak = 0,
  });

  factory MasterySnapshot.fromJson(Map<String, dynamic> json) {
    return MasterySnapshot(
      totalConcepts: json['totalConcepts'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      learning: json['learning'] as int? ?? 0,
      newCount: json['newCount'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
    );
  }

  final int totalConcepts;
  final int mastered;
  final int learning;
  final int newCount;
  final int streak;

  double get masteryRatio =>
      totalConcepts > 0 ? mastered / totalConcepts : 0.0;

  Map<String, dynamic> toJson() => {
        'totalConcepts': totalConcepts,
        'mastered': mastered,
        'learning': learning,
        'newCount': newCount,
        'streak': streak,
      };
}
