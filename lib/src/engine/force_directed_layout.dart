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
    List<Offset?>? initialPositions,
    Set<int>? pinnedNodes,
  }) {
    _pinnedNodes = pinnedNodes ?? {};
    _k = math.sqrt((width * height) / math.max(nodeCount, 1));
    _positions = _initPositions(seed, initialPositions);

    // When seeded with existing positions, scale temperature by the fraction
    // of new nodes so settled nodes shift gently instead of flying around.
    final fullTemp = math.min(width, height) / 4;
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
  late Set<int> _pinnedNodes;

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

    // Apply capped displacement (pinned nodes stay fixed)
    for (var i = 0; i < nodeCount; i++) {
      if (_pinnedNodes.contains(i)) continue;
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
