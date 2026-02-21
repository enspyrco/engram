import 'package:flutter/material.dart';

import '../../models/team_goal.dart';

/// A card displaying a team goal's progress, contributors, and deadline.
class TeamGoalCard extends StatelessWidget {
  const TeamGoalCard({required this.goal, super.key});

  final TeamGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgencyColor = _deadlineColor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + goal type badge
            Row(
              children: [
                Expanded(
                  child: Text(goal.title, style: theme.textTheme.titleSmall),
                ),
                _GoalTypeBadge(type: goal.type),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progressFraction,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: urgencyColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),

            // Progress text + deadline
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(goal.progressFraction * 100).toStringAsFixed(0)}% of ${goal.targetValue}',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  _deadlineText(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: urgencyColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contributors
            if (goal.contributions.isNotEmpty)
              Wrap(
                spacing: 4,
                children:
                    goal.contributions.entries.map((entry) {
                      return Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          '+${entry.value.toStringAsFixed(1)}',
                          style: theme.textTheme.labelSmall,
                        ),
                        avatar: CircleAvatar(
                          radius: 10,
                          child: Text(
                            entry.key.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Color _deadlineColor() {
    final now = DateTime.now().toUtc();
    final deadline = goal.deadline;
    final created = goal.createdAt;

    if (now.isAfter(deadline)) return Colors.red;

    final totalDuration = deadline.difference(created).inHours;
    if (totalDuration <= 0) return Colors.amber;

    final remaining = deadline.difference(now).inHours;
    final fraction = remaining / totalDuration;

    if (fraction > 0.5) return Colors.green;
    if (fraction > 0.2) return Colors.amber;
    return Colors.red;
  }

  String _deadlineText() {
    final deadline = goal.deadline;
    final now = DateTime.now().toUtc();
    final diff = deadline.difference(now);

    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 1) return '${diff.inDays}d left';
    if (diff.inHours > 1) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }
}

class _GoalTypeBadge extends StatelessWidget {
  const _GoalTypeBadge({required this.type});

  final GoalType type;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (type) {
      GoalType.clusterMastery => ('Cluster', Icons.hub),
      GoalType.healthTarget => ('Health', Icons.favorite),
      GoalType.streakTarget => ('Streak', Icons.local_fire_department),
    };

    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label, style: const TextStyle(fontSize: 10)),
      avatar: Icon(icon, size: 14),
      visualDensity: VisualDensity.compact,
    );
  }
}
