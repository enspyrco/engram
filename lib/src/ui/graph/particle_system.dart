import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/network_health.dart';
import 'graph_edge.dart';

/// A single particle that flows along a graph edge.
class Particle {
  Particle({
    required this.edgeIndex,
    required this.progress,
    required this.speed,
    required this.opacity,
  });

  /// Index into the edge list this particle belongs to.
  final int edgeIndex;

  /// Position along the edge (0.0 = source, 1.0 = target).
  double progress;

  /// Speed in progress-units per frame.
  double speed;

  /// Current opacity (modulated by health).
  double opacity;
}

/// Manages ambient particles flowing along graph edges.
///
/// Particles represent "neural activity" in the knowledge network. Their
/// behavior changes based on network health tier:
///
/// - **Healthy**: Steady flow, warm green glow
/// - **Brownout**: Slower flow, flickering opacity, yellow-ish
/// - **Cascade**: Erratic speed, red particles
/// - **Fracture**: Particles absent from fractured edges, arcs on healing ones
/// - **Collapse**: Almost no particles (1-2 on the "last spark" node's edges)
class ParticleSystem {
  ParticleSystem({int seed = 0}) : _random = Random(seed);

  final Random _random;
  final List<Particle> _particles = [];

  /// Number of particles to maintain per edge at healthy tier.
  static const _particlesPerEdgeHealthy = 2;

  /// Current particles (read-only snapshot for painting).
  List<Particle> get particles => List.unmodifiable(_particles);

  /// Initialize particles for the given edges and health tier.
  void initialize(List<GraphEdge> edges, HealthTier tier) {
    _particles.clear();

    final particlesPerEdge = _particleCountForTier(tier);
    for (var i = 0; i < edges.length; i++) {
      for (var j = 0; j < particlesPerEdge; j++) {
        _particles.add(
          Particle(
            edgeIndex: i,
            progress: _random.nextDouble(),
            speed: _baseSpeedForTier(tier) * (0.5 + _random.nextDouble()),
            opacity: _baseOpacityForTier(tier),
          ),
        );
      }
    }
  }

  /// Advance all particles by one frame. Called from the Ticker.
  void step(HealthTier tier) {
    for (final particle in _particles) {
      // Advance position
      particle.progress += particle.speed;

      // Wrap around
      if (particle.progress > 1.0) {
        particle.progress -= 1.0;
      }

      // Modulate opacity based on tier
      switch (tier) {
        case HealthTier.healthy:
          particle.opacity = 0.6 + 0.4 * sin(particle.progress * pi * 2);
        case HealthTier.brownout:
          // Flickering effect
          particle.opacity = 0.3 + 0.5 * _random.nextDouble();
        case HealthTier.cascade:
          // Erratic
          particle.speed =
              _baseSpeedForTier(tier) * (0.2 + 1.5 * _random.nextDouble());
          particle.opacity = 0.4 + 0.6 * _random.nextDouble();
        case HealthTier.fracture:
        case HealthTier.collapse:
          particle.opacity = 0.1 + 0.2 * _random.nextDouble();
      }
    }
  }

  int _particleCountForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return _particlesPerEdgeHealthy;
      case HealthTier.brownout:
        return 1;
      case HealthTier.cascade:
        return 1;
      case HealthTier.fracture:
        return 0;
      case HealthTier.collapse:
        return 0;
    }
  }

  double _baseSpeedForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return 0.008;
      case HealthTier.brownout:
        return 0.005;
      case HealthTier.cascade:
        return 0.012;
      case HealthTier.fracture:
        return 0.003;
      case HealthTier.collapse:
        return 0.001;
    }
  }

  double _baseOpacityForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return 0.7;
      case HealthTier.brownout:
        return 0.5;
      case HealthTier.cascade:
        return 0.6;
      case HealthTier.fracture:
        return 0.2;
      case HealthTier.collapse:
        return 0.1;
    }
  }
}

/// Paints particles along graph edges.
class ParticlePainter extends CustomPainter {
  ParticlePainter({
    required this.particles,
    required this.edges,
    required this.tier,
  });

  final List<Particle> particles;
  final List<GraphEdge> edges;
  final HealthTier tier;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (particle.edgeIndex >= edges.length) continue;

      final edge = edges[particle.edgeIndex];
      final src = edge.source.position;
      final tgt = edge.target.position;

      // Interpolate position along edge
      final pos = Offset.lerp(src, tgt, particle.progress)!;

      final color = _particleColorForTier(tier);
      final radius = tier == HealthTier.healthy ? 3.0 : 2.0;

      // Glow
      canvas.drawCircle(
        pos,
        radius * 2.5,
        Paint()
          ..color = color.withValues(alpha: particle.opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Core
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = color.withValues(alpha: particle.opacity),
      );
    }
  }

  Color _particleColorForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return const Color(0xFF4CAF50); // green
      case HealthTier.brownout:
        return const Color(0xFFFFC107); // amber
      case HealthTier.cascade:
        return const Color(0xFFFF5722); // deep orange
      case HealthTier.fracture:
        return const Color(0xFFE91E63); // pink-red
      case HealthTier.collapse:
        return const Color(0xFF9E9E9E); // grey
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
