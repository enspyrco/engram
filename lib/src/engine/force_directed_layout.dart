import 'dart:math' as math;
import 'dart:ui';

/// A Fruchterman-Reingold force-directed layout engine.
///
/// Pure Dart — no Flutter widget dependency. Each call to [step] advances the
/// simulation by one frame. When the layout has converged (temperature drops
/// below [settledThreshold]), [step] returns `false` and the caller can stop
/// its animation ticker.
class ForceDirectedLayout {
  ForceDirectedLayout({
    required this.nodeCount,
    required this.edges,
    this.width = 800.0,
    this.height = 600.0,
    this.settledThreshold = 0.05,
    this.velocityDecay = 0.4,
    int? seed,
    List<Offset?>? initialPositions,
    Set<int>? pinnedNodes,
  }) {
    _pinnedNodes = pinnedNodes ?? {};
    _k = math.sqrt((width * height) / math.max(nodeCount, 1));
    _positions = _initPositions(seed, initialPositions);
    _velocities = List<Offset>.filled(nodeCount, Offset.zero);

    // When seeded with existing positions, scale temperature by the fraction
    // of new nodes so settled nodes shift gently instead of flying around.
    final fullTemp = math.min(width, height) / 6;
    if (initialPositions == null) {
      _temperature = fullTemp;
    } else {
      final newCount = initialPositions.where((p) => p == null).length +
          math.max(0, nodeCount - initialPositions.length);
      final fraction = nodeCount > 0 ? newCount / nodeCount : 1.0;
      _temperature = fraction >= 1.0
          ? fullTemp
          : math.max(fullTemp * fraction, fullTemp * 0.15);
    }
    _initialTemperature = _temperature;
  }

  final int nodeCount;

  /// Each edge is a pair of node indices [source, target].
  final List<(int, int)> edges;

  final double width;
  final double height;
  final double settledThreshold;

  /// Friction coefficient: each step, velocity is multiplied by
  /// `(1 - velocityDecay)`. Higher values = more friction = faster stopping.
  final double velocityDecay;

  late double _k;
  late double _temperature;
  late double _initialTemperature;
  late List<Offset> _positions;
  late List<Offset> _velocities;
  late Set<int> _pinnedNodes;

  /// Current node positions, indexed by node index.
  List<Offset> get positions => List.unmodifiable(_positions);

  /// Current simulation temperature (drives max displacement per step).
  double get temperature => _temperature;

  /// Number of nodes that are pinned (immovable anchors).
  int get pinnedCount => _pinnedNodes.length;

  /// Current per-node velocities.
  List<Offset> get velocities => List.unmodifiable(_velocities);

  /// Maximum velocity magnitude across all nodes (useful for debug overlay).
  double get maxVelocity {
    var max = 0.0;
    for (final v in _velocities) {
      final mag = v.distance;
      if (mag > max) max = mag;
    }
    return max;
  }

  /// Whether the simulation has converged.
  bool get isSettled => _temperature < settledThreshold;

  /// Advance the simulation by one step.
  ///
  /// Uses velocity-based physics (d3-force style): forces are scaled by alpha
  /// and accumulated into per-node velocity vectors. Velocity decays each step
  /// via [velocityDecay], producing smooth motion with momentum and coasting.
  ///
  /// Returns `true` if still moving, `false` if settled.
  bool step() {
    if (isSettled) return false;

    final alpha = _temperature / _initialTemperature;
    final forces = List<Offset>.filled(nodeCount, Offset.zero);

    // Repulsive forces between all node pairs
    for (var i = 0; i < nodeCount; i++) {
      for (var j = i + 1; j < nodeCount; j++) {
        final delta = _positions[i] - _positions[j];
        final dist = math.max(delta.distance, 0.01);
        final force = (_k * _k) / dist;
        final normalized = delta / dist;
        forces[i] = forces[i] + normalized * force;
        forces[j] = forces[j] - normalized * force;
      }
    }

    // Attractive forces along edges
    for (final (src, tgt) in edges) {
      final delta = _positions[tgt] - _positions[src];
      final dist = math.max(delta.distance, 0.01);
      final force = (dist * dist) / _k;
      final normalized = delta / dist;
      forces[src] = forces[src] + normalized * force;
      forces[tgt] = forces[tgt] - normalized * force;
    }

    // Velocity integration (pinned nodes stay fixed)
    const margin = 30.0;
    final decay = 1.0 - velocityDecay;
    for (var i = 0; i < nodeCount; i++) {
      if (_pinnedNodes.contains(i)) {
        _velocities[i] = Offset.zero;
        continue;
      }

      // Accumulate force scaled by alpha, then apply friction
      _velocities[i] = (_velocities[i] + forces[i] * alpha) * decay;

      // Cap velocity magnitude at temperature (prevents explosion from
      // strong FR forces while preserving coasting once forces diminish)
      final speed = _velocities[i].distance;
      if (speed > _temperature) {
        _velocities[i] *= _temperature / speed;
      }

      // Apply velocity to position
      final newPos = _positions[i] + _velocities[i];

      // Clamp to bounds and zero velocity at walls
      final clampedX = newPos.dx.clamp(margin, width - margin);
      final clampedY = newPos.dy.clamp(margin, height - margin);
      if (clampedX != newPos.dx) {
        _velocities[i] = Offset(0, _velocities[i].dy);
      }
      if (clampedY != newPos.dy) {
        _velocities[i] = Offset(_velocities[i].dx, 0);
      }
      _positions[i] = Offset(clampedX, clampedY);
    }

    // Cool down
    _temperature *= 0.97;

    return !isSettled;
  }

  /// Set positions directly (e.g. for testing with pre-settled layout).
  void setPositions(List<Offset> positions) {
    assert(positions.length == nodeCount);
    _positions = List.of(positions);
    _velocities = List<Offset>.filled(nodeCount, Offset.zero);
  }

  /// Force the layout to settle immediately.
  void settle() {
    _temperature = 0.0;
    _velocities = List<Offset>.filled(nodeCount, Offset.zero);
  }

  /// Build initial positions, using [initial] where non-null and filling the
  /// rest with random offsets. Note: pre-seeded entries skip RNG calls, so the
  /// random sequence for later nodes diverges from a cold-start layout. This is
  /// intentional — strict seed-determinism only matters for the null case
  /// (first build / tests).
  List<Offset> _initPositions(int? seed, List<Offset?>? initial) {
    final rng = math.Random(seed);
    const margin = 30.0;
    return List.generate(nodeCount, (i) {
      final provided =
          (initial != null && i < initial.length) ? initial[i] : null;
      if (provided != null) return provided;
      return Offset(
        margin + rng.nextDouble() * (width - 2 * margin),
        margin + rng.nextDouble() * (height - 2 * margin),
      );
    });
  }
}
