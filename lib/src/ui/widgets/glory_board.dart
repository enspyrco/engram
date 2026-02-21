import 'package:flutter/material.dart';

import '../../models/glory_entry.dart';

/// A ranked leaderboard of team glory — "Who's Holding the Line."
///
/// Shows each contributor with their point breakdown (guardian, mission, goal).
/// Top contributor gets a gold highlight.
class GloryBoard extends StatelessWidget {
  const GloryBoard({required this.entries, super.key});

  final List<GloryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No glory yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Guard clusters, complete missions, and contribute to goals to earn glory.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isTop = index == 0 && entry.totalPoints > 0;
        return _GloryEntryTile(
          entry: entry,
          rank: index + 1,
          isTopContributor: isTop,
        );
      },
    );
  }
}

class _GloryEntryTile extends StatelessWidget {
  const _GloryEntryTile({
    required this.entry,
    required this.rank,
    required this.isTopContributor,
  });

  final GloryEntry entry;
  final int rank;
  final bool isTopContributor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color:
          isTopContributor
              ? const Color(0xFFFFD700).withValues(alpha: 0.12)
              : null,
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundImage:
                  entry.photoUrl != null ? NetworkImage(entry.photoUrl!) : null,
              child:
                  entry.photoUrl == null
                      ? Text(
                        entry.displayName.isNotEmpty
                            ? entry.displayName[0].toUpperCase()
                            : '?',
                      )
                      : null,
            ),
            if (isTopContributor)
              const Positioned(
                top: -6,
                right: -6,
                child: Icon(
                  Icons.workspace_premium,
                  size: 18,
                  color: Color(0xFFFFD700),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Text(
              '#$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(entry.displayName)),
            Text(
              '${entry.totalPoints}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Wrap(
          spacing: 8,
          children: [
            _PointBadge(
              icon: Icons.shield,
              count: entry.guardianPoints,
              label: 'Guard',
            ),
            _PointBadge(
              icon: Icons.build,
              count: entry.missionPoints,
              label: 'Mission',
            ),
            _PointBadge(
              icon: Icons.flag,
              count: entry.goalPoints,
              label: 'Goal',
            ),
            _PointBadge(
              icon: Icons.sync,
              count: entry.relayPoints,
              label: 'Relay',
            ),
            _PointBadge(
              icon: Icons.thunderstorm,
              count: entry.stormPoints,
              label: 'Storm',
            ),
          ],
        ),
      ),
    );
  }
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text('$count', style: theme.textTheme.labelSmall),
      ],
    );
  }
}
