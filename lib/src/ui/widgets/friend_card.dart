import 'package:flutter/material.dart';

import '../../models/friend.dart';

/// Displays a friend with avatar, name, mastery bar, streak,
/// and action buttons for Challenge and Nudge.
class FriendCard extends StatelessWidget {
  const FriendCard({
    super.key,
    required this.friend,
    this.onChallenge,
    this.onNudge,
  });

  final Friend friend;
  final VoidCallback? onChallenge;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = friend.masterySnapshot;
    final masteryRatio = snapshot?.masteryRatio ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: friend.photoUrl != null
                  ? NetworkImage(friend.photoUrl!)
                  : null,
              child: friend.photoUrl == null
                  ? Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  if (snapshot != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: masteryRatio,
                              minHeight: 6,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${snapshot.mastered}/${snapshot.totalConcepts}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (snapshot.streak > 0)
                      Text(
                        '${snapshot.streak}-day streak',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ] else
                    Text(
                      'No mastery data yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.flash_on),
                  tooltip: 'Challenge',
                  onPressed: onChallenge,
                  iconSize: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_active),
                  tooltip: 'Nudge',
                  onPressed: onNudge,
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
