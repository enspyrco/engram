import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/mastery_state.dart';
import 'graph_edge.dart';
import 'graph_node.dart';
import 'team_avatar_cache.dart';
import 'team_node.dart';

/// Renders the force-directed graph on a [Canvas].
///
/// Paints in layer order: team-to-concept edges, concept edges, concept nodes,
/// concept labels, team avatar nodes.
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.nodes,
    required this.edges,
    this.teamNodes = const [],
    this.avatarCache,
    this.selectedNodeId,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<TeamNode> teamNodes;
  final TeamAvatarCache? avatarCache;
  final String? selectedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 1: Team-to-concept connection lines (behind everything)
    _paintTeamEdges(canvas);
    // Layer 2: Concept edges
    _paintEdges(canvas);
    // Layer 3: Concept nodes
    for (final node in nodes) {
      _paintNode(canvas, node);
    }
    // Layer 4: Concept labels
    for (final node in nodes) {
      _paintLabel(canvas, node);
    }
    // Layer 5: Team avatar nodes (on top)
    for (final teamNode in teamNodes) {
      _paintTeamNode(canvas, teamNode);
    }
  }

  void _paintTeamEdges(Canvas canvas) {
    if (teamNodes.isEmpty) return;

    final nodeById = <String, GraphNode>{for (final n in nodes) n.id: n};

    for (final teamNode in teamNodes) {
      for (final conceptId in teamNode.masteredConceptIds) {
        final conceptNode = nodeById[conceptId];
        if (conceptNode == null) continue;

        canvas.drawLine(
          teamNode.position,
          conceptNode.position,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _paintEdges(Canvas canvas) {
    for (final edge in edges) {
      final paint = Paint()
        ..color = edge.isDependency
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = edge.isDependency ? 2.0 : 1.0
        ..style = PaintingStyle.stroke;

      final src = edge.source.position;
      final tgt = edge.target.position;
      canvas.drawLine(src, tgt, paint);

      if (edge.isDependency) {
        _paintArrowhead(canvas, src, tgt, paint);
      }
    }
  }

  void _paintArrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from);
    final dist = direction.distance;
    if (dist < 1.0) return;

    final unit = direction / dist;
    final tip = to - unit * 18.0;
    final perpendicular = Offset(-unit.dy, unit.dx);
    const arrowSize = 8.0;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - unit.dx * arrowSize + perpendicular.dx * arrowSize * 0.5,
        tip.dy - unit.dy * arrowSize + perpendicular.dy * arrowSize * 0.5,
      )
      ..lineTo(
        tip.dx - unit.dx * arrowSize - perpendicular.dx * arrowSize * 0.5,
        tip.dy - unit.dy * arrowSize - perpendicular.dy * arrowSize * 0.5,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintNode(Canvas canvas, GraphNode node) {
    final color = masteryColors[node.masteryState] ?? Colors.grey;
    final isSelected = node.id == selectedNodeId;

    if (node.masteryState == MasteryState.mastered) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          node.position,
          node.radius * 2.5,
          [
            color.withValues(alpha: 0.4),
            color.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(node.position, node.radius * 2.5, glowPaint);
    }

    if (isSelected) {
      canvas.drawCircle(
        node.position,
        node.radius + 4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final opacity = 0.4 + 0.6 * node.freshness;
    final nodePaint = Paint()..color = color.withValues(alpha: opacity);
    canvas.drawCircle(node.position, node.radius, nodePaint);

    canvas.drawCircle(
      node.position,
      node.radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintLabel(Canvas canvas, GraphNode node) {
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 10,
        maxLines: 1,
        ellipsis: '...',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 10,
      ))
      ..addText(node.name);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 100));

    final labelOffset = Offset(
      node.position.dx - paragraph.width / 2,
      node.position.dy + node.radius + 4,
    );
    canvas.drawParagraph(paragraph, labelOffset);
  }

  void _paintTeamNode(Canvas canvas, TeamNode teamNode) {
    final isSelected = teamNode.id == selectedNodeId;
    final pos = teamNode.position;
    final r = teamNode.radius;

    // Health ring: green (healthy) → red (neglected)
    final healthColor = Color.lerp(Colors.red, Colors.green, teamNode.healthRatio)!;
    canvas.drawCircle(
      pos,
      r + 3,
      Paint()
        ..color = healthColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Selection ring
    if (isSelected) {
      canvas.drawCircle(
        pos,
        r + 7,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Avatar image or initial fallback
    final avatarImage = avatarCache?.getAvatar(teamNode.friend.uid);
    if (avatarImage != null) {
      _paintAvatarImage(canvas, pos, r, avatarImage);
    } else {
      _paintAvatarFallback(canvas, pos, r, teamNode.displayName);
    }

    // Name label below avatar
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 9,
        maxLines: 1,
        ellipsis: '...',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 9,
      ))
      ..addText(teamNode.displayName);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 80));

    canvas.drawParagraph(
      paragraph,
      Offset(pos.dx - paragraph.width / 2, pos.dy + r + 6),
    );
  }

  void _paintAvatarImage(
    Canvas canvas,
    Offset center,
    double radius,
    ui.Image image,
  ) {
    canvas.save();
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(circlePath);

    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dstRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
    canvas.restore();
  }

  void _paintAvatarFallback(
    Canvas canvas,
    Offset center,
    double radius,
    String name,
  ) {
    // Colored circle based on name hash
    final hue = (name.hashCode % 360).abs().toDouble();
    final bgColor = HSLColor.fromAHSL(1.0, hue, 0.5, 0.4).toColor();
    canvas.drawCircle(center, radius, Paint()..color = bgColor);

    // Initial letter
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 16),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: 16))
      ..addText(initial);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 40));

    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - paragraph.width / 2, center.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.teamNodes != teamNodes ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}
