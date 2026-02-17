import 'package:flutter/material.dart';

import 'graph_edge.dart';

/// Tap card showing relationship details between two concepts.
///
/// Used by both [StaticGraphWidget] and [ForceDirectedGraphWidget] when the
/// user taps on an edge.
class EdgePanel extends StatelessWidget {
  const EdgePanel({required this.edge, super.key});

  final GraphEdge edge;

  @override
  Widget build(BuildContext context) {
    final color = edge.isDependency
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.6);

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  edge.isDependency ? Icons.arrow_forward : Icons.link,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    edge.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${edge.source.name}  \u2192  ${edge.target.name}',
              style: const TextStyle(fontSize: 12),
            ),
            if (edge.relationship.description != null) ...[
              const SizedBox(height: 4),
              Text(
                edge.relationship.description!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (edge.isDependency) ...[
              const SizedBox(height: 4),
              Text(
                'Dependency',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
