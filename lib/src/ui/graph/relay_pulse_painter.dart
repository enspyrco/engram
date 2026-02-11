import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'graph_edge.dart';

/// A single relay pulse traveling along an edge.
@immutable
class RelayPulse {
  const RelayPulse({
    required this.fromConceptId,
    required this.toConceptId,
    required this.progress,
    this.speed = 0.02,
  });

  final String fromConceptId;
  final String toConceptId;

  /// Position along the edge (0.0 = source, 1.0 = target).
  final double progress;

  /// Speed in progress-units per frame.
  final double speed;

  RelayPulse advanced() => RelayPulse(
        fromConceptId: fromConceptId,
        toConceptId: toConceptId,
        progress: progress + speed,
        speed: speed,
      );

  bool get isComplete => progress >= 1.0;
}

/// Paints bright cyan relay pulses traveling along specific graph edges.
///
/// Each pulse has a trailing effect (3-4 dots at decreasing opacity behind
/// the lead particle). On full relay completion, pulses cascade with
/// staggered delays for a celebratory light show.
class RelayPulsePainter extends CustomPainter {
  RelayPulsePainter({
    required this.pulses,
    required this.edges,
    required this.relayConceptIds,
  });

  final List<RelayPulse> pulses;
  final List<GraphEdge> edges;

  /// Concept IDs that are part of an active relay — get a cyan ring highlight.
  final Set<String> relayConceptIds;

  static const _leadRadius = 5.0;
  static const _trailCount = 3;
  static const _trailSpacing = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    // Highlight relay concept nodes with cyan ring
    _paintRelayHighlights(canvas);

    // Paint each pulse with trail effect
    for (final pulse in pulses) {
      final edge = _findEdge(pulse);
      if (edge == null) continue;

      final src = edge.source.position;
      final tgt = edge.target.position;

      // Trail dots (behind the lead)
      for (var i = _trailCount; i >= 1; i--) {
        final trailProgress = (pulse.progress - i * _trailSpacing).clamp(0.0, 1.0);
        final trailPos = Offset.lerp(src, tgt, trailProgress)!;
        final trailOpacity = (1.0 - i / (_trailCount + 1)) * 0.6;
        final trailRadius = _leadRadius * (1.0 - i * 0.15);

        // Glow
        canvas.drawCircle(
          trailPos,
          trailRadius * 2.0,
          Paint()
            ..color = Colors.cyan.withValues(alpha: trailOpacity * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        // Core
        canvas.drawCircle(
          trailPos,
          trailRadius,
          Paint()..color = Colors.cyan.withValues(alpha: trailOpacity),
        );
      }

      // Lead particle
      final leadPos = Offset.lerp(src, tgt, pulse.progress.clamp(0.0, 1.0))!;

      // Bright glow
      canvas.drawCircle(
        leadPos,
        _leadRadius * 3.0,
        Paint()
          ..shader = ui.Gradient.radial(
            leadPos,
            _leadRadius * 3.0,
            [
              Colors.white.withValues(alpha: 0.6),
              Colors.cyan.withValues(alpha: 0.0),
            ],
          ),
      );
      // White-cyan core
      canvas.drawCircle(
        leadPos,
        _leadRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        leadPos,
        _leadRadius * 0.6,
        Paint()..color = Colors.cyan,
      );
    }
  }

  void _paintRelayHighlights(Canvas canvas) {
    for (final edge in edges) {
      for (final node in [edge.source, edge.target]) {
        if (!relayConceptIds.contains(node.id)) continue;

        canvas.drawCircle(
          node.position,
          node.radius + 4,
          Paint()
            ..color = Colors.cyan.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }
  }

  GraphEdge? _findEdge(RelayPulse pulse) {
    for (final edge in edges) {
      if (edge.source.id == pulse.fromConceptId &&
          edge.target.id == pulse.toConceptId) {
        return edge;
      }
      // Also check reverse direction
      if (edge.source.id == pulse.toConceptId &&
          edge.target.id == pulse.fromConceptId) {
        return edge;
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(RelayPulsePainter oldDelegate) => true;
}
