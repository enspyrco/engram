import 'dart:math';

import 'package:flutter/material.dart';

import 'graph_edge.dart';

/// Paints a stormy overlay on the graph during active entropy storms.
///
/// Effects:
/// - Semi-transparent dark overlay (scales with intensity)
/// - Sweeping chaotic particles (sine wave + linear drift)
/// - Edge jitter (perpendicular offset on all edges)
///
/// Independent of catastrophe painters — they stack visually.
class StormOverlayPainter extends CustomPainter {
  StormOverlayPainter({
    required this.edges,
    required this.animationProgress,
    this.intensity = 1.0,
  });

  final List<GraphEdge> edges;

  /// Animation progress (0.0 – 1.0), repeating.
  final double animationProgress;

  /// Storm intensity (0.0 – 1.0). Controls overlay opacity and particle density.
  final double intensity;

  static const _particleCount = 40;
  static const _particleRadius = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: intensity * 0.15),
    );

    // Chaotic storm particles
    _paintStormParticles(canvas, size);

    // Edge jitter
    _paintEdgeJitter(canvas);
  }

  void _paintStormParticles(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * intensity);

    for (var i = 0; i < _particleCount; i++) {
      // Deterministic-looking chaos from index + animationProgress
      final seed = i * 137.508; // Golden angle in degrees
      final phase = (seed + animationProgress * 360) % 360;
      final radian = phase * pi / 180;

      // Sine wave drift + linear motion
      final x = (seed % size.width) +
          sin(radian * 2) * 30 +
          animationProgress * 80 * (i.isEven ? 1 : -1);
      final y = (seed * 0.618 % size.height) +
          cos(radian * 3) * 20 +
          animationProgress * 40;

      // Wrap around canvas
      final wrappedX = x % size.width;
      final wrappedY = y % size.height;

      canvas.drawCircle(
        Offset(wrappedX, wrappedY),
        _particleRadius,
        particlePaint,
      );
    }
  }

  void _paintEdgeJitter(Canvas canvas) {
    final jitterPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06 * intensity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < edges.length; i++) {
      final edge = edges[i];
      final src = edge.source.position;
      final tgt = edge.target.position;

      final direction = tgt - src;
      final dist = direction.distance;
      if (dist < 1.0) continue;

      final unit = direction / dist;
      final perpendicular = Offset(-unit.dy, unit.dx);

      // More aggressive jitter than brownout static
      final jitterAmount =
          4.0 * sin(animationProgress * pi * 6 + i * 1.3) * intensity;
      final mid = Offset.lerp(src, tgt, 0.5)!;

      canvas.drawLine(
        mid + perpendicular * jitterAmount,
        mid - perpendicular * jitterAmount,
        jitterPaint,
      );
    }
  }

  @override
  bool shouldRepaint(StormOverlayPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.intensity != intensity;
  }
}
