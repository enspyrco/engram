import 'package:flutter/material.dart';

import '../../models/nudge.dart';

/// Card showing an incoming nudge on the friends screen.
class NudgeCard extends StatelessWidget {
  const NudgeCard({super.key, required this.nudge, required this.onReviewNow});

  final Nudge nudge;
  final VoidCallback onReviewNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${nudge.fromName} nudged you about ${nudge.conceptName}!',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (nudge.message != null) ...[
              const SizedBox(height: 4),
              Text(
                '"${nudge.message}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onReviewNow,
                child: const Text('Review now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
