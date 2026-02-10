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
    this.settledThreshold = 0.1,
    int? seed,
  }) {
    _k = math.sqrt((width * height) / math.max(nodeCount, 1));
    _temperature = math.min(width, height) / 4;
    _positions = _randomPositions(seed);
  }

  final int nodeCount;

  /// Each edge is a pair of node indices [source, target].
  final List<(int, int)> edges;

  final double width;
  final double height;
  final double settledThreshold;

  late double _k;
  late double _temperature;
  late List<Offset> _positions;

  /// Current node positions, indexed by node index.
  List<Offset> get positions => List.unmodifiable(_positions);

  /// Whether the simulation has converged.
  bool get isSettled => _temperature < settledThreshold;

  /// Advance the simulation by one step.
  ///
  /// Returns `true` if still moving, `false` if settled.
  bool step() {
    if (isSettled) return false;

    final displacements = List<Offset>.filled(nodeCount, Offset.zero);

    // Repulsive forces between all node pairs
    for (var i = 0; i < nodeCount; i++) {
      for (var j = i + 1; j < nodeCount; j++) {
        final delta = _positions[i] - _positions[j];
        final dist = math.max(delta.distance, 0.01);
        final force = (_k * _k) / dist;
        final normalized = delta / dist;
        displacements[i] = displacements[i] + normalized * force;
        displacements[j] = displacements[j] - normalized * force;
      }
    }

    // Attractive forces along edges
    for (final (src, tgt) in edges) {
      final delta = _positions[tgt] - _positions[src];
      final dist = math.max(delta.distance, 0.01);
      final force = (dist * dist) / _k;
      final normalized = delta / dist;
      displacements[src] = displacements[src] + normalized * force;
      displacements[tgt] = displacements[tgt] - normalized * force;
    }

    // Apply capped displacement
    for (var i = 0; i < nodeCount; i++) {
      final disp = displacements[i];
      final dist = math.max(disp.distance, 0.01);
      final capped = math.min(dist, _temperature);
      final normalized = disp / dist;
      var newPos = _positions[i] + normalized * capped;

      // Keep nodes within bounds (with margin)
      const margin = 30.0;
      newPos = Offset(
        newPos.dx.clamp(margin, width - margin),
        newPos.dy.clamp(margin, height - margin),
      );
      _positions[i] = newPos;
    }

    // Cool down
    _temperature *= 0.95;

    return !isSettled;
  }

  /// Set positions directly (e.g. for testing with pre-settled layout).
  void setPositions(List<Offset> positions) {
    assert(positions.length == nodeCount);
    _positions = List.of(positions);
  }

  /// Force the layout to settle immediately.
  void settle() {
    _temperature = 0.0;
  }

  List<Offset> _randomPositions(int? seed) {
    final rng = math.Random(seed);
    const margin = 30.0;
    return List.generate(nodeCount, (_) {
      return Offset(
        margin + rng.nextDouble() * (width - 2 * margin),
        margin + rng.nextDouble() * (height - 2 * margin),
      );
    });
  }
}
