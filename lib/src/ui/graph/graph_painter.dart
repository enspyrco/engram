import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/mastery_state.dart';
import '../../models/relationship.dart';
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
    this.draggingNodeId,
    this.guardianMap = const {},
    this.currentUserUid,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<TeamNode> teamNodes;
  final TeamAvatarCache? avatarCache;
  final String? selectedNodeId;

  /// The ID of the node currently being dragged (scaled up with glow ring).
  final String? draggingNodeId;

  /// Maps concept ID → guardian UID (if the concept's cluster has a guardian).
  final Map<String, String> guardianMap;

  /// Current user's UID, for highlighting their guarded nodes.
  final String? currentUserUid;

  // -- Concept node visual constants --

  /// Scale factor applied to a node's radius while being dragged.
  static const dragScaleFactor = 1.2;

  /// Gap between the drag glow ring and the scaled node edge.
  static const dragGlowGap = 6.0;

  /// Stroke width of the drag glow ring.
  static const dragGlowStrokeWidth = 3.0;

  /// Gap between the selection ring and the node edge.
  static const selectionRingGap = 4.0;

  /// Radial glow extends to this multiple of node radius for mastered nodes.
  static const masteryGlowRadiusMultiplier = 2.5;

  /// Gap between the guardian gold ring and the node edge.
  static const guardianRingGap = 2.0;

  /// Minimum opacity for node fill (at freshness = 0).
  static const minFreshnessOpacity = 0.4;

  /// Gap between the node edge and the label text below it.
  static const labelGap = 4.0;

  /// Maximum width for concept label text layout.
  static const labelMaxWidth = 100.0;

  // -- Edge / arrowhead constants --

  /// Offset from the target node center where the arrowhead tip is placed.
  /// Keeps the arrowhead visually outside the target node circle.
  static const arrowTipOffset = 18.0;

  /// Size of the arrowhead triangle (base and height).
  static const arrowSize = 8.0;

  // -- Team node visual constants --

  /// Gap between the team node health ring and the avatar edge.
  static const teamHealthRingGap = 3.0;

  /// Gap between the team node selection ring and the avatar edge.
  static const teamSelectionRingGap = 7.0;

  /// Gap between the team avatar edge and the name label below it.
  static const teamLabelGap = 6.0;

  /// Maximum width for team node name label text layout.
  static const teamLabelMaxWidth = 80.0;

  // -- Shield badge constants --

  /// Position offset as a fraction of node radius for the shield badge.
  static const shieldBadgeOffset = 0.7;

  /// Half-size of the shield badge icon.
  static const shieldBadgeSize = 5.0;

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
      final isDragging = node.id == draggingNodeId;
      _paintLabel(
        canvas,
        node,
        effectiveRadius: isDragging ? node.radius * dragScaleFactor : null,
      );
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

  /// Dash length for analogy/contrast edges.
  static const _dashLength = 6.0;

  /// Gap between dashes for analogy/contrast edges.
  static const _dashGap = 4.0;

  void _paintEdges(Canvas canvas) {
    for (final edge in edges) {
      final paint = _paintForType(edge.type);
      final src = edge.source.position;
      final tgt = edge.target.position;
      final isDashed =
          edge.type == RelationshipType.analogy ||
          edge.type == RelationshipType.contrast;

      if (isDashed) {
        _paintDashedLine(canvas, src, tgt, paint);
      } else {
        canvas.drawLine(src, tgt, paint);
      }

      if (_hasArrowhead(edge.type)) {
        _paintArrowhead(canvas, src, tgt, paint);
      }
    }
  }

  /// Whether the given relationship type should render an arrowhead.
  static bool _hasArrowhead(RelationshipType type) =>
      type == RelationshipType.prerequisite || type == RelationshipType.enables;

  /// Returns a [Paint] configured for the given [RelationshipType].
  static Paint _paintForType(RelationshipType type) {
    final paint = Paint()..style = PaintingStyle.stroke;
    switch (type) {
      case RelationshipType.prerequisite:
        paint
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = 2.0;
      case RelationshipType.generalization:
        paint
          ..color = Colors.cyan.withValues(alpha: 0.5)
          ..strokeWidth = 1.5;
      case RelationshipType.composition:
        paint
          ..color = Colors.teal.withValues(alpha: 0.5)
          ..strokeWidth = 1.5;
      case RelationshipType.enables:
        paint
          ..color = Colors.purple.withValues(alpha: 0.5)
          ..strokeWidth = 1.5;
      case RelationshipType.analogy:
        paint
          ..color = Colors.orange.withValues(alpha: 0.35)
          ..strokeWidth = 1.0;
      case RelationshipType.contrast:
        paint
          ..color = Colors.pink.withValues(alpha: 0.35)
          ..strokeWidth = 1.0;
      case RelationshipType.relatedTo:
        paint
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 1.0;
    }
    return paint;
  }

  /// Draws a dashed line between [from] and [to].
  void _paintDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = to - from;
    final dist = direction.distance;
    if (dist < 1.0) return;

    final unit = direction / dist;
    var drawn = 0.0;
    while (drawn < dist) {
      final start = from + unit * drawn;
      final end = from + unit * (drawn + _dashLength).clamp(0.0, dist);
      canvas.drawLine(start, end, paint);
      drawn += _dashLength + _dashGap;
    }
  }

  void _paintArrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from);
    final dist = direction.distance;
    if (dist < 1.0) return;

    final unit = direction / dist;
    final tip = to - unit * arrowTipOffset;
    final perpendicular = Offset(-unit.dy, unit.dx);

    final path =
        Path()
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
    final isDragging = node.id == draggingNodeId;
    final effectiveRadius =
        isDragging ? node.radius * dragScaleFactor : node.radius;

    // Drag glow ring
    if (isDragging) {
      canvas.drawCircle(
        node.position,
        effectiveRadius + dragGlowGap,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = dragGlowStrokeWidth,
      );
    }

    if (node.masteryState == MasteryState.mastered) {
      final glowRadius = node.radius * masteryGlowRadiusMultiplier;
      final glowPaint =
          Paint()
            ..shader = ui.Gradient.radial(node.position, glowRadius, [
              color.withValues(alpha: 0.4),
              color.withValues(alpha: 0.0),
            ]);
      canvas.drawCircle(node.position, glowRadius, glowPaint);
    }

    if (isSelected) {
      canvas.drawCircle(
        node.position,
        effectiveRadius + selectionRingGap,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final opacity =
        minFreshnessOpacity + (1.0 - minFreshnessOpacity) * node.freshness;
    final nodePaint = Paint()..color = color.withValues(alpha: opacity);
    canvas.drawCircle(node.position, effectiveRadius, nodePaint);

    canvas.drawCircle(
      node.position,
      effectiveRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Guardian indicators
    final guardianUid = guardianMap[node.id];
    if (guardianUid != null) {
      // Gold border ring for nodes guarded by the current user
      if (guardianUid == currentUserUid) {
        canvas.drawCircle(
          node.position,
          effectiveRadius + guardianRingGap,
          Paint()
            ..color = const Color(0xFFFFD700).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // Small shield badge at top-right of guarded nodes
      _paintShieldBadge(canvas, node.position, effectiveRadius);
    }
  }

  void _paintShieldBadge(Canvas canvas, Offset center, double radius) {
    final badgeCenter = Offset(
      center.dx + radius * shieldBadgeOffset,
      center.dy - radius * shieldBadgeOffset,
    );
    const badgeSize = shieldBadgeSize;

    final path =
        Path()
          ..moveTo(badgeCenter.dx, badgeCenter.dy - badgeSize)
          ..lineTo(badgeCenter.dx + badgeSize, badgeCenter.dy - badgeSize * 0.3)
          ..lineTo(badgeCenter.dx + badgeSize * 0.7, badgeCenter.dy + badgeSize)
          ..lineTo(badgeCenter.dx, badgeCenter.dy + badgeSize * 0.6)
          ..lineTo(badgeCenter.dx - badgeSize * 0.7, badgeCenter.dy + badgeSize)
          ..lineTo(badgeCenter.dx - badgeSize, badgeCenter.dy - badgeSize * 0.3)
          ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintLabel(Canvas canvas, GraphNode node, {double? effectiveRadius}) {
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: 10,
              maxLines: 1,
              ellipsis: '...',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
            ),
          )
          ..addText(node.name);

    final paragraph =
        paragraphBuilder.build()
          ..layout(const ui.ParagraphConstraints(width: labelMaxWidth));

    final labelOffset = Offset(
      node.position.dx - paragraph.width / 2,
      node.position.dy + (effectiveRadius ?? node.radius) + labelGap,
    );
    canvas.drawParagraph(paragraph, labelOffset);
  }

  void _paintTeamNode(Canvas canvas, TeamNode teamNode) {
    final isSelected = teamNode.id == selectedNodeId;
    final pos = teamNode.position;
    final r = teamNode.radius;

    // Health ring: green (healthy) → red (neglected)
    final healthColor =
        Color.lerp(Colors.red, Colors.green, teamNode.healthRatio)!;
    canvas.drawCircle(
      pos,
      r + teamHealthRingGap,
      Paint()
        ..color = healthColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Selection ring
    if (isSelected) {
      canvas.drawCircle(
        pos,
        r + teamSelectionRingGap,
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
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: 9,
              maxLines: 1,
              ellipsis: '...',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9,
            ),
          )
          ..addText(teamNode.displayName);

    final paragraph =
        paragraphBuilder.build()
          ..layout(const ui.ParagraphConstraints(width: teamLabelMaxWidth));

    canvas.drawParagraph(
      paragraph,
      Offset(pos.dx - paragraph.width / 2, pos.dy + r + teamLabelGap),
    );
  }

  void _paintAvatarImage(
    Canvas canvas,
    Offset center,
    double radius,
    ui.Image image,
  ) {
    canvas.save();
    final circlePath =
        Path()..addOval(Rect.fromCircle(center: center, radius: radius));
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
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 16),
          )
          ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: 16))
          ..addText(initial);

    final paragraph =
        paragraphBuilder.build()
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
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.draggingNodeId != draggingNodeId ||
        oldDelegate.guardianMap != guardianMap ||
        oldDelegate.currentUserUid != currentUserUid;
  }
}
