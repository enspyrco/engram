import 'package:flutter/material.dart';

import '../../models/repair_mission.dart';

/// Card displaying an active repair mission with progress tracking.
///
/// Shows a progress bar, remaining concept count, and the 1.5x bonus badge.
/// Used on the dashboard and in catastrophe-related screens.
class RepairMissionCard extends StatelessWidget {
  const RepairMissionCard({
    required this.mission,
    this.onTap,
    super.key,
  });

  final RepairMission mission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = mission.progress;
    final remaining = mission.remaining;
    final total = mission.conceptIds.length;
    final reviewed = mission.reviewedConceptIds.length;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.build_circle,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Repair Mission',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _BonusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.onSurface
                      .withValues(alpha: 0.1),
                  color: _progressColor(progress),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$reviewed / $total concepts reviewed',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '$remaining remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining > 0
                          ? theme.colorScheme.error
                          : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _progressColor(double progress) {
    if (progress < 0.3) return const Color(0xFFF44336);
    if (progress < 0.7) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }
}

class _BonusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '1.5x',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
