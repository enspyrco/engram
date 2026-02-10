import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/network_health.dart';
import 'graph_edge.dart';
import 'graph_node.dart';

/// Paints catastrophe visual effects layered on top of the base graph.
///
/// Effects vary by health tier:
///
/// - **Brownout**: Flickering node opacity, muted edge glow
/// - **Cascade**: Red "fracture lines" on stressed edges, visible tension
/// - **Fracture**: Bright crack propagation along weakest edges, screen shake
///   offset, drifting island effect
/// - **Collapse**: Edges snap (dashed), nodes dim, single "spark" node glows
class CatastrophePainter extends CustomPainter {
  CatastrophePainter({
    required this.nodes,
    required this.edges,
    required this.tier,
    required this.animationProgress,
    this.shakeOffset = Offset.zero,
    this.sparkNodeId,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final HealthTier tier;

  /// Animation progress for tier transition effects (0.0 – 1.0).
  final double animationProgress;

  /// Screen shake offset (applied during fracture events).
  final Offset shakeOffset;

  /// The "last spark" node during collapse (most recently reviewed).
  final String? sparkNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(shakeOffset.dx, shakeOffset.dy);

    switch (tier) {
      case HealthTier.healthy:
        break; // No catastrophe effects
      case HealthTier.brownout:
        _paintBrownout(canvas);
      case HealthTier.cascade:
        _paintCascade(canvas);
      case HealthTier.fracture:
        _paintFracture(canvas);
      case HealthTier.collapse:
        _paintCollapse(canvas);
    }

    canvas.restore();
  }

  /// Tier 1: Fading nodes flicker. Edges develop visual static.
  void _paintBrownout(Canvas canvas) {
    // Edge static: thin white noise lines near edges
    final staticPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 * animationProgress)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final src = edge.source.position;
      final tgt = edge.target.position;
      final mid = Offset.lerp(src, tgt, 0.5)!;
      final perpendicular = Offset(-(tgt.dy - src.dy), tgt.dx - src.dx);
      final norm = perpendicular.distance;
      if (norm < 1.0) continue;

      final offset = perpendicular / norm * 3.0 * sin(animationProgress * pi * 4);
      canvas.drawLine(mid + offset, mid - offset, staticPaint);
    }

    // Flicker overlay on fading/due nodes
    for (final node in nodes) {
      if (node.freshness > 0.7) continue;

      final flickerAlpha =
          0.15 * sin(animationProgress * pi * 6 + node.position.dx) + 0.15;
      canvas.drawCircle(
        node.position,
        node.radius + 2,
        Paint()
          ..color = Colors.amber.withValues(alpha: flickerAlpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  /// Tier 2: Red fracture lines on stressed edges. Physical distortion feel.
  void _paintCascade(Canvas canvas) {
    // Jagged red lines on edges between low-freshness nodes
    final fracturePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6 * animationProgress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final avgFreshness =
          (edge.source.freshness + edge.target.freshness) / 2;
      if (avgFreshness > 0.5) continue;

      final src = edge.source.position;
      final tgt = edge.target.position;
      _paintJaggedLine(canvas, src, tgt, fracturePaint);
    }

    // Countdown-style glow on stressed cluster boundaries
    for (final node in nodes) {
      if (node.freshness > 0.4) continue;

      final pulseAlpha =
          0.3 * sin(animationProgress * pi * 2).abs();
      canvas.drawCircle(
        node.position,
        node.radius * 1.8,
        Paint()
          ..color = Colors.red.withValues(alpha: pulseAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  /// Tier 3: Bright crack propagation. The big one.
  void _paintFracture(Canvas canvas) {
    // Bright crack along weakest edges (lowest freshness)
    final crackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * animationProgress)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.4 * animationProgress)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final edge in edges) {
      final avgFreshness =
          (edge.source.freshness + edge.target.freshness) / 2;
      if (avgFreshness > 0.3) continue;

      final src = edge.source.position;
      final tgt = edge.target.position;

      // Propagating crack: only draw up to animationProgress along the edge
      final crackedTo = Offset.lerp(src, tgt, animationProgress)!;

      // Glow behind the crack
      canvas.drawLine(src, crackedTo, glowPaint);
      // Bright crack line
      _paintJaggedLine(canvas, src, crackedTo, crackPaint);
    }

    // Electrical arc particles at crack tips
    for (final edge in edges) {
      final avgFreshness =
          (edge.source.freshness + edge.target.freshness) / 2;
      if (avgFreshness > 0.3) continue;

      final src = edge.source.position;
      final tgt = edge.target.position;
      final tipPos = Offset.lerp(src, tgt, animationProgress)!;

      _paintArcSparks(canvas, tipPos);
    }
  }

  /// Tier 4: Edges snap. Darkness. One spark remains.
  void _paintCollapse(Canvas canvas) {
    // Darken everything
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 2000, 2000),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6 * animationProgress),
    );

    // Dashed edges (snapping)
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final src = edge.source.position;
      final tgt = edge.target.position;
      _paintDashedLine(canvas, src, tgt, dashPaint);
    }

    // The last spark: one node glows brightly
    if (sparkNodeId != null) {
      final sparkNode = nodes.where((n) => n.id == sparkNodeId).firstOrNull;
      if (sparkNode != null) {
        final pulseRadius =
            sparkNode.radius * (2.0 + 1.5 * sin(animationProgress * pi * 2));

        canvas.drawCircle(
          sparkNode.position,
          pulseRadius,
          Paint()
            ..shader = ui.Gradient.radial(
              sparkNode.position,
              pulseRadius,
              [
                Colors.amber.withValues(alpha: 0.8),
                Colors.amber.withValues(alpha: 0.0),
              ],
            ),
        );

        // Bright core
        canvas.drawCircle(
          sparkNode.position,
          sparkNode.radius * 1.2,
          Paint()..color = Colors.amber,
        );
      }
    }
  }

  /// Draw a jagged/zigzag line between two points (fracture crack effect).
  void _paintJaggedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final path = Path()..moveTo(from.dx, from.dy);

    final direction = to - from;
    final dist = direction.distance;
    if (dist < 1.0) return;

    final unit = direction / dist;
    final perpendicular = Offset(-unit.dy, unit.dx);

    const segments = 8;

    for (var i = 1; i <= segments; i++) {
      final t = i / segments;
      final basePoint = Offset.lerp(from, to, t)!;
      final jitter = (i % 2 == 0 ? 1.0 : -1.0) *
          3.0 *
          sin(animationProgress * pi * 3 + i);
      final point = basePoint + perpendicular * jitter;

      if (i < segments) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(to.dx, to.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// Draw a dashed line (collapse effect — edges "snapping").
  void _paintDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = to - from;
    final dist = direction.distance;
    if (dist < 1.0) return;

    final unit = direction / dist;
    const dashLength = 6.0;
    const gapLength = 4.0;

    var drawn = 0.0;
    var drawing = true;

    while (drawn < dist) {
      final segmentEnd =
          (drawn + (drawing ? dashLength : gapLength)).clamp(0.0, dist);

      if (drawing) {
        canvas.drawLine(
          from + unit * drawn,
          from + unit * segmentEnd,
          paint,
        );
      }

      drawn = segmentEnd;
      drawing = !drawing;
    }
  }

  /// Paint small electrical arc sparks at a point.
  void _paintArcSparks(Canvas canvas, Offset center) {
    final sparkPaint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 4; i++) {
      final angle = (i / 4) * pi * 2 + animationProgress * pi;
      final length = 6.0 + 4.0 * sin(animationProgress * pi * 8 + i);
      final endpoint = center + Offset(cos(angle), sin(angle)) * length;
      canvas.drawLine(center, endpoint, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(CatastrophePainter oldDelegate) {
    return oldDelegate.tier != tier ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.shakeOffset != shakeOffset ||
        oldDelegate.sparkNodeId != sparkNodeId;
  }
}
