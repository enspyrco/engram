import 'package:meta/meta.dart';

/// The type of target a team goal tracks.
enum GoalType { clusterMastery, healthTarget, streakTarget }

/// A cooperative goal set by a team member for the wiki group.
///
/// Progress is tracked via [contributions] — each member's contribution
/// score accumulates toward [targetValue]. Auto-completes when the sum
/// of contributions reaches the target or expires at [deadline].
@immutable
class TeamGoal {
  const TeamGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.targetCluster,
    required this.targetValue,
    required this.createdAt,
    required this.deadline,
    required this.createdByUid,
    this.contributions = const {},
    this.completedAt,
  });

  factory TeamGoal.fromJson(Map<String, dynamic> json) {
    return TeamGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: GoalType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => GoalType.clusterMastery,
      ),
      targetCluster: json['targetCluster'] as String?,
      targetValue: (json['targetValue'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      deadline: DateTime.parse(json['deadline'] as String),
      createdByUid: json['createdByUid'] as String,
      contributions:
          (json['contributions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'] as String)
              : null,
    );
  }

  final String id;
  final String title;
  final String description;
  final GoalType type;

  /// Cluster label for [GoalType.clusterMastery] goals.
  final String? targetCluster;

  /// Target value — e.g. 0.8 for 80% mastery.
  final double targetValue;

  final DateTime createdAt;
  final DateTime deadline;
  final String createdByUid;

  /// UID → contribution score. Accumulates across review sessions.
  final Map<String, double> contributions;

  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  /// Total progress toward the goal (sum of all contributions).
  double get totalProgress {
    if (contributions.isEmpty) return 0.0;
    return contributions.values.fold(0.0, (a, b) => a + b);
  }

  /// Progress as a fraction of target (clamped to 1.0).
  double get progressFraction {
    if (targetValue <= 0) return 1.0;
    return (totalProgress / targetValue).clamp(0.0, 1.0);
  }

  TeamGoal withContribution(String uid, double amount) {
    final updated = Map<String, double>.of(contributions);
    updated[uid] = (updated[uid] ?? 0.0) + amount;
    return TeamGoal(
      id: id,
      title: title,
      description: description,
      type: type,
      targetCluster: targetCluster,
      targetValue: targetValue,
      createdAt: createdAt,
      deadline: deadline,
      createdByUid: createdByUid,
      contributions: updated,
      completedAt: completedAt,
    );
  }

  TeamGoal withCompleted(DateTime timestamp) => TeamGoal(
    id: id,
    title: title,
    description: description,
    type: type,
    targetCluster: targetCluster,
    targetValue: targetValue,
    createdAt: createdAt,
    deadline: deadline,
    createdByUid: createdByUid,
    contributions: contributions,
    completedAt: timestamp,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'targetCluster': targetCluster,
    'targetValue': targetValue,
    'createdAt': createdAt.toIso8601String(),
    'deadline': deadline.toIso8601String(),
    'createdByUid': createdByUid,
    'contributions': contributions,
    'completedAt': completedAt?.toIso8601String(),
  };
}
