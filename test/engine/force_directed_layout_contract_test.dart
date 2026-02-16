import 'dart:ui';

import 'package:engram/src/engine/force_directed_layout.dart';
import 'package:test/test.dart';

// ── Inline helpers ──────────────────────────────────────────────────────

ForceDirectedLayout makeLayout({
  int nodeCount = 4,
  List<(int, int)>? edges,
  double width = 800.0,
  double height = 600.0,
  int seed = 42,
  List<Offset?>? initialPositions,
  Set<int>? pinnedNodes,
  double theta = 0.9,
  int quadtreeThreshold = 30,
}) {
  return ForceDirectedLayout(
    nodeCount: nodeCount,
    edges: edges ?? List.generate(nodeCount - 1, (i) => (i, i + 1)),
    width: width,
    height: height,
    seed: seed,
    initialPositions: initialPositions,
    pinnedNodes: pinnedNodes,
    theta: theta,
    quadtreeThreshold: quadtreeThreshold,
  );
}

int runToSettled(ForceDirectedLayout layout, {int maxSteps = 1000}) {
  var steps = 0;
  while (layout.step()) {
    steps++;
    if (steps >= maxSteps) break;
  }
  return steps;
}

double pairwiseMinDistance(List<Offset> positions) {
  var minDist = double.infinity;
  for (var i = 0; i < positions.length; i++) {
    for (var j = i + 1; j < positions.length; j++) {
      final dist = (positions[i] - positions[j]).distance;
      if (dist < minDist) minDist = dist;
    }
  }
  return minDist;
}

void main() {
  group('Pinned node immutability', () {
    test('pinned nodes preserve exact position through full simulation', () {
      const pin0 = Offset(200, 150);
      const pin1 = Offset(500, 400);

      final layout = makeLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        initialPositions: [pin0, pin1, null, null],
        pinnedNodes: {0, 1},
      );

      runToSettled(layout);

      // Bit-identical — pinned nodes skip displacement entirely via `continue`
      expect(layout.positions[0], pin0);
      expect(layout.positions[1], pin1);
    });

    test('pinned nodes exert forces on unpinned neighbors', () {
      const pinnedPos = Offset(400, 300);

      final layout = makeLayout(
        nodeCount: 2,
        edges: [(0, 1)],
        initialPositions: [pinnedPos, null],
        pinnedNodes: {0},
      );

      final initialPos1 = layout.positions[1];
      runToSettled(layout);

      // Unpinned node 1 moved due to forces from pinned node 0
      final displacement = (layout.positions[1] - initialPos1).distance;
      expect(displacement, greaterThan(1.0));
      // Pinned node 0 unchanged
      expect(layout.positions[0], pinnedPos);
    });

    test('all-pinned layout settles with positions preserved', () {
      final allPinned = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        initialPositions: [
          const Offset(100, 100),
          const Offset(300, 300),
          const Offset(500, 200),
        ],
        pinnedNodes: {0, 1, 2},
      );

      final coldStart = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );

      final pinnedSteps = runToSettled(allPinned);
      final coldSteps = runToSettled(coldStart);

      expect(allPinned.isSettled, isTrue);
      // All positions unchanged — no displacement applied
      expect(allPinned.positions[0], const Offset(100, 100));
      expect(allPinned.positions[1], const Offset(300, 300));
      expect(allPinned.positions[2], const Offset(500, 200));
      // Settles faster than cold start (lower starting temperature)
      expect(pinnedSteps, lessThan(coldSteps));
    });
  });

  group('Temperature scaling', () {
    test('cold start temperature equals min(w,h) / 6', () {
      final layout = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );

      // Default 800x600 → min(800, 600) / 6 = 100
      expect(layout.temperature, 100.0);
    });

    test('temperature proportional to fraction of new nodes', () {
      // 3 seeded + 1 new → fraction = 0.25 → temp = max(100*0.25, 100*0.15) = 25
      final lowFraction = makeLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        initialPositions: [
          const Offset(100, 100),
          const Offset(200, 200),
          const Offset(300, 300),
          null,
        ],
      );

      // 2 seeded + 2 new → fraction = 0.5 → temp = max(100*0.5, 100*0.15) = 50
      final highFraction = makeLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        initialPositions: [
          const Offset(100, 100),
          const Offset(200, 200),
          null,
          null,
        ],
      );

      expect(lowFraction.temperature, closeTo(25.0, 0.001));
      expect(highFraction.temperature, closeTo(50.0, 0.001));
      expect(lowFraction.temperature, lessThan(highFraction.temperature));
    });

    test('temperature floor at 15% of full temperature', () {
      // 9 seeded + 1 new → fraction = 0.1 → max(100*0.1, 100*0.15) = 15
      final layout = makeLayout(
        nodeCount: 10,
        initialPositions: [
          const Offset(100, 100),
          const Offset(200, 100),
          const Offset(300, 100),
          const Offset(400, 100),
          const Offset(500, 100),
          const Offset(100, 300),
          const Offset(200, 300),
          const Offset(300, 300),
          const Offset(400, 300),
          null, // one new node
        ],
      );

      const fullTemp = 100.0; // min(800, 600) / 6
      expect(layout.temperature, closeTo(fullTemp * 0.15, 0.001));
    });
  });

  group('Incremental layout stability', () {
    test('adding nodes does not displace pinned nodes', () {
      // Phase 1: settle a 3-node layout
      final initial = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );
      runToSettled(initial);
      final settledPositions = List<Offset>.from(initial.positions);

      // Phase 2: create a 5-node layout with first 3 pinned at settled positions
      final incremental = makeLayout(
        nodeCount: 5,
        edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
        initialPositions: [
          settledPositions[0],
          settledPositions[1],
          settledPositions[2],
          null,
          null,
        ],
        pinnedNodes: {0, 1, 2},
      );
      runToSettled(incremental);

      // Pinned nodes preserve exact positions
      expect(incremental.positions[0], settledPositions[0]);
      expect(incremental.positions[1], settledPositions[1]);
      expect(incremental.positions[2], settledPositions[2]);
    });

    test('incremental add settles faster than cold start', () {
      // Settle 3 nodes first
      final seed = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );
      runToSettled(seed);
      final settledPositions = List<Offset>.from(seed.positions);

      // Incremental: 3 seeded + 2 new
      final incremental = makeLayout(
        nodeCount: 5,
        edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
        initialPositions: [
          settledPositions[0],
          settledPositions[1],
          settledPositions[2],
          null,
          null,
        ],
      );

      // Cold start: 5 fresh nodes
      final coldStart = makeLayout(
        nodeCount: 5,
        edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
      );

      final incrSteps = runToSettled(incremental);
      final coldSteps = runToSettled(coldStart);

      expect(incrSteps, lessThan(coldSteps));
    });

    test('batch addition: settled nodes maintain minimum separation', () {
      // Phase 1: settle 5 nodes
      final initial = makeLayout(
        nodeCount: 5,
        edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
      );
      runToSettled(initial);
      final settledPositions = List<Offset>.from(initial.positions);

      // Phase 2: add 5 more nodes (10 total), pin the first 5
      final batch = makeLayout(
        nodeCount: 10,
        edges: List.generate(9, (i) => (i, i + 1)),
        initialPositions: [
          ...settledPositions,
          null,
          null,
          null,
          null,
          null,
        ],
        pinnedNodes: {0, 1, 2, 3, 4},
      );
      runToSettled(batch);

      // All pairwise distances > 36 (2x node radius of 18)
      final minDist = pairwiseMinDistance(batch.positions);
      expect(minDist, greaterThan(36.0));
    });
  });

  group('Centering and bounds', () {
    test('settled centroid near canvas center', () {
      final layout = makeLayout(
        nodeCount: 10,
        edges: List.generate(9, (i) => (i, i + 1)),
      );
      runToSettled(layout);

      var cx = 0.0;
      var cy = 0.0;
      for (final pos in layout.positions) {
        cx += pos.dx;
        cy += pos.dy;
      }
      cx /= layout.nodeCount;
      cy /= layout.nodeCount;

      expect(cx, closeTo(400.0, 50.0));
      expect(cy, closeTo(300.0, 50.0));
    });

    test('custom canvas size centroid near center', () {
      final layout = makeLayout(
        nodeCount: 10,
        edges: List.generate(9, (i) => (i, i + 1)),
        width: 1200,
        height: 900,
      );
      runToSettled(layout);

      var cx = 0.0;
      var cy = 0.0;
      for (final pos in layout.positions) {
        cx += pos.dx;
        cy += pos.dy;
      }
      cx /= layout.nodeCount;
      cy /= layout.nodeCount;

      expect(cx, closeTo(600.0, 50.0));
      expect(cy, closeTo(450.0, 50.0));
    });

    test('safety boundary catches runaway nodes', () {
      final layout = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );

      // Force a node way outside the generous boundary
      layout.setPositions([
        const Offset(-2000, -2000),
        const Offset(400, 300),
        const Offset(500, 400),
      ]);

      // After a step the safety net clamps to [-width, 2*width] x
      // [-height, 2*height] (symmetric 1x padding around the canvas).
      layout.step();

      for (final pos in layout.positions) {
        expect(pos.dx, greaterThanOrEqualTo(-800.0));
        expect(pos.dx, lessThanOrEqualTo(1600.0));
        expect(pos.dy, greaterThanOrEqualTo(-600.0));
        expect(pos.dy, lessThanOrEqualTo(1200.0));
      }
    });
  });

  group('Centering force skip with pinned nodes', () {
    test('centering force skipped when pinned nodes exist', () {
      // Place pinned nodes off-center — centering must NOT shift them
      const pin0 = Offset(100, 100);
      const pin1 = Offset(200, 100);

      final layout = makeLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        initialPositions: [pin0, pin1, null, null],
        pinnedNodes: {0, 1},
      );
      runToSettled(layout);

      // Pinned positions preserved (centering didn't shift them)
      expect(layout.positions[0], pin0);
      expect(layout.positions[1], pin1);

      // Centroid is NOT necessarily near canvas center — that's correct,
      // because centering bails out entirely when any node is pinned
      var cx = 0.0;
      var cy = 0.0;
      for (final pos in layout.positions) {
        cx += pos.dx;
        cy += pos.dy;
      }
      cx /= layout.nodeCount;
      cy /= layout.nodeCount;

      // Centroid won't be perfectly centered — pinned nodes anchor the
      // layout off-center and centering force doesn't fight them
      final distFromCenter =
          (Offset(cx, cy) - const Offset(400.0, 300.0)).distance;
      expect(distFromCenter, greaterThan(10.0),
          reason: 'centroid should NOT be perfectly centered with off-center pins');
    });
  });

  group('Barnes-Hut quadtree', () {
    test('BH produces similar results to exact for 50 nodes', () {
      // Build a 50-node chain graph
      const n = 50;
      final edges = List.generate(n - 1, (i) => (i, i + 1));

      final exact = makeLayout(
        nodeCount: n,
        edges: edges,
        quadtreeThreshold: n + 1, // force exact
      );
      final bh = makeLayout(
        nodeCount: n,
        edges: edges,
        quadtreeThreshold: 0, // force Barnes-Hut
        theta: 0.5, // moderate accuracy
      );

      runToSettled(exact);
      runToSettled(bh);

      // Centroid should be similar (both centered)
      var exactCx = 0.0, exactCy = 0.0;
      var bhCx = 0.0, bhCy = 0.0;
      for (var i = 0; i < n; i++) {
        exactCx += exact.positions[i].dx;
        exactCy += exact.positions[i].dy;
        bhCx += bh.positions[i].dx;
        bhCy += bh.positions[i].dy;
      }
      exactCx /= n;
      exactCy /= n;
      bhCx /= n;
      bhCy /= n;

      expect(bhCx, closeTo(exactCx, 100.0));
      expect(bhCy, closeTo(exactCy, 100.0));
    });

    test('theta=0 produces exact-equivalent results', () {
      const n = 40;
      final edges = List.generate(n - 1, (i) => (i, i + 1));

      final exact = makeLayout(
        nodeCount: n,
        edges: edges,
        quadtreeThreshold: n + 1, // force exact
      );
      final bhExact = makeLayout(
        nodeCount: n,
        edges: edges,
        quadtreeThreshold: 0, // force BH
        theta: 0.0, // theta=0 means never approximate
      );

      runToSettled(exact);
      runToSettled(bhExact);

      // With theta=0, BH traverses every leaf — should match exact closely
      for (var i = 0; i < n; i++) {
        expect(bhExact.positions[i].dx,
            closeTo(exact.positions[i].dx, 5.0),
            reason: 'node $i x');
        expect(bhExact.positions[i].dy,
            closeTo(exact.positions[i].dy, 5.0),
            reason: 'node $i y');
      }
    });

    test('threshold gates BH vs exact selection', () {
      // 10 nodes with threshold 5 → BH path
      final bhLayout = makeLayout(
        nodeCount: 10,
        quadtreeThreshold: 5,
      );
      // 10 nodes with threshold 20 → exact path
      final exactLayout = makeLayout(
        nodeCount: 10,
        quadtreeThreshold: 20,
      );

      // Both should settle and produce valid layouts
      runToSettled(bhLayout);
      runToSettled(exactLayout);
      expect(bhLayout.isSettled, isTrue);
      expect(exactLayout.isSettled, isTrue);
    });

    test('BH works with pinned nodes', () {
      const n = 40;
      final edges = List.generate(n - 1, (i) => (i, i + 1));

      final layout = makeLayout(
        nodeCount: n,
        edges: edges,
        quadtreeThreshold: 0, // force BH
        initialPositions: [
          const Offset(200, 150),
          const Offset(500, 400),
          ...List.filled(n - 2, null),
        ],
        pinnedNodes: {0, 1},
      );
      runToSettled(layout);

      // Pinned positions preserved
      expect(layout.positions[0], const Offset(200, 150));
      expect(layout.positions[1], const Offset(500, 400));
    });
  });

  group('Convergence guarantees', () {
    test('cooling rate is 0.97 per step', () {
      final layout = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );

      final tempBefore = layout.temperature;
      layout.step();
      final tempAfter = layout.temperature;

      expect(tempAfter, closeTo(tempBefore * 0.97, 1e-10));
    });

    test('step returns false when settled', () {
      final layout = makeLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
      );

      runToSettled(layout);
      expect(layout.isSettled, isTrue);
      expect(layout.step(), isFalse);
    });
  });
}
