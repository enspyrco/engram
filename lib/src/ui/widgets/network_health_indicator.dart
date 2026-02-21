import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/network_health.dart';

/// Compact health gauge for the dashboard.
///
/// Displays a circular arc with the health score percentage, colored by tier.
/// Tapping expands to show per-cluster breakdown.
class NetworkHealthIndicator extends StatelessWidget {
  const NetworkHealthIndicator({required this.health, this.onTap, super.key});

  final NetworkHealth health;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorForTier(health.tier);
    final pct = (health.score * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CustomPaint(
                      painter: _HealthArcPainter(
                        progress: health.score,
                        color: color,
                      ),
                      child: Center(
                        child: Text(
                          '$pct%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Health',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        _TierChip(tier: health.tier, color: color),
                      ],
                    ),
                  ),
                ],
              ),
              if (health.clusterHealth.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...health.clusterHealth.entries.map(
                  (entry) => _ClusterRow(label: entry.key, score: entry.value),
                ),
              ],
              if (health.atRiskCriticalPaths > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${health.atRiskCriticalPaths} critical path${health.atRiskCriticalPaths == 1 ? '' : 's'} at risk',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return const Color(0xFF4CAF50);
      case HealthTier.brownout:
        return const Color(0xFFFFC107);
      case HealthTier.cascade:
        return const Color(0xFFFF9800);
      case HealthTier.fracture:
        return const Color(0xFFF44336);
      case HealthTier.collapse:
        return const Color(0xFF9E9E9E);
    }
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier, required this.color});

  final HealthTier tier;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = _tierLabel(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _tierLabel(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return 'Healthy';
      case HealthTier.brownout:
        return 'Brownout';
      case HealthTier.cascade:
        return 'Cascade Warning';
      case HealthTier.fracture:
        return 'Network Fracture';
      case HealthTier.collapse:
        return 'Total Collapse';
    }
  }
}

class _ClusterRow extends StatelessWidget {
  const _ClusterRow({required this.label, required this.score});

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = Color.lerp(Colors.red, Colors.green, score)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$pct%',
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a circular arc representing health progress.
class _HealthArcPainter extends CustomPainter {
  _HealthArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HealthArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
