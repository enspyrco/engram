import 'package:flutter/material.dart';

import '../../models/relationship.dart';
import 'graph_edge.dart';

/// Tap card showing relationship details between two concepts.
///
/// Used by [ForceDirectedGraphWidget] when the user taps on an edge.
class EdgePanel extends StatelessWidget {
  const EdgePanel({required this.edge, super.key});

  final GraphEdge edge;

  @override
  Widget build(BuildContext context) {
    final type = edge.type;
    final visual = _visualForType(type);

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
                Icon(visual.icon, size: 14, color: visual.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    edge.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: visual.color,
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
            const SizedBox(height: 4),
            Text(
              visual.badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: visual.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual attributes for a relationship type in the [EdgePanel].
class _EdgeVisual {
  const _EdgeVisual({
    required this.icon,
    required this.color,
    required this.badgeText,
  });

  final IconData icon;
  final Color color;
  final String badgeText;
}

_EdgeVisual _visualForType(RelationshipType type) {
  switch (type) {
    case RelationshipType.prerequisite:
      return _EdgeVisual(
        icon: Icons.arrow_forward,
        color: Colors.white.withValues(alpha: 0.9),
        badgeText: 'Prerequisite',
      );
    case RelationshipType.generalization:
      return const _EdgeVisual(
        icon: Icons.account_tree,
        color: Colors.cyan,
        badgeText: 'Generalization',
      );
    case RelationshipType.composition:
      return const _EdgeVisual(
        icon: Icons.extension,
        color: Colors.teal,
        badgeText: 'Composition',
      );
    case RelationshipType.enables:
      return const _EdgeVisual(
        icon: Icons.bolt,
        color: Colors.purple,
        badgeText: 'Enables',
      );
    case RelationshipType.analogy:
      return const _EdgeVisual(
        icon: Icons.compare_arrows,
        color: Colors.orange,
        badgeText: 'Analogy',
      );
    case RelationshipType.contrast:
      return const _EdgeVisual(
        icon: Icons.swap_horiz,
        color: Colors.pink,
        badgeText: 'Contrast',
      );
    case RelationshipType.relatedTo:
      return _EdgeVisual(
        icon: Icons.link,
        color: Colors.white.withValues(alpha: 0.6),
        badgeText: 'Related',
      );
  }
}
