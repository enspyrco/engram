import 'package:meta/meta.dart';

import 'mastery_snapshot.dart';

@immutable
class DashboardStats {
  const DashboardStats({
    this.documentCount = 0,
    this.conceptCount = 0,
    this.relationshipCount = 0,
    this.quizItemCount = 0,
    this.newCount = 0,
    this.learningCount = 0,
    this.masteredCount = 0,
    this.dueCount = 0,
    this.foundationalCount = 0,
    this.unlockedCount = 0,
    this.lockedCount = 0,
    this.hasCycles = false,
  });

  final int documentCount;
  final int conceptCount;
  final int relationshipCount;
  final int quizItemCount;
  final int newCount;
  final int learningCount;
  final int masteredCount;
  final int dueCount;
  final int foundationalCount;
  final int unlockedCount;
  final int lockedCount;
  final bool hasCycles;

  bool get isEmpty => conceptCount == 0;

  MasterySnapshot toMasterySnapshot({int streak = 0}) => MasterySnapshot(
        totalConcepts: conceptCount,
        mastered: masteredCount,
        learning: learningCount,
        newCount: newCount,
        streak: streak,
      );
}
