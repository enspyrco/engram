import 'dart:ui';

import 'package:engram/src/engine/force_directed_layout.dart';
import 'package:test/test.dart';

void main() {
  group('ForceDirectedLayout', () {
    test('positions change after a step (convergence)', () {
      final layout = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
      );

      final before = List<Offset>.from(layout.positions);
      layout.step();
      final after = layout.positions;

      // At least one position should have moved
      final moved = Iterable.generate(
        3,
      ).any((i) => (after[i] - before[i]).distance > 0.01);
      expect(moved, isTrue);
    });

    test('settles after enough steps', () {
      final layout = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
      );

      var steps = 0;
      while (layout.step()) {
        steps++;
        if (steps > 500) break; // safety limit
      }

      expect(layout.isSettled, isTrue);
      expect(steps, lessThan(500));
    });

    test('deterministic with same seed', () {
      final layout1 = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 99,
      );
      final layout2 = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 99,
      );

      // Run both to completion
      while (layout1.step()) {}
      while (layout2.step()) {}

      for (var i = 0; i < 3; i++) {
        expect(
          layout1.positions[i].dx,
          closeTo(layout2.positions[i].dx, 0.001),
        );
        expect(
          layout1.positions[i].dy,
          closeTo(layout2.positions[i].dy, 0.001),
        );
      }
    });

    test('setPositions overrides layout', () {
      final layout = ForceDirectedLayout(
        nodeCount: 2,
        edges: [(0, 1)],
        seed: 42,
      );

      final custom = [const Offset(100, 100), const Offset(200, 200)];
      layout.setPositions(custom);

      expect(layout.positions[0], const Offset(100, 100));
      expect(layout.positions[1], const Offset(200, 200));
    });

    test('settle() stops the simulation immediately', () {
      final layout = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
      );

      expect(layout.isSettled, isFalse);
      layout.settle();
      expect(layout.isSettled, isTrue);
      expect(layout.step(), isFalse);
    });

    test('single node settles without edges', () {
      final layout = ForceDirectedLayout(nodeCount: 1, edges: [], seed: 42);

      var steps = 0;
      while (layout.step()) {
        steps++;
        if (steps > 500) break;
      }

      expect(layout.isSettled, isTrue);
    });

    test('initialPositions preserves pre-seeded positions', () {
      const seeded0 = Offset(200, 150);
      const seeded1 = Offset(400, 300);

      final layout = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
        initialPositions: [seeded0, seeded1, null, null],
      );

      // Pre-seeded positions appear verbatim before any steps
      expect(layout.positions[0], seeded0);
      expect(layout.positions[1], seeded1);
      // New nodes got random positions (not zero)
      expect(layout.positions[2], isNot(Offset.zero));
      expect(layout.positions[3], isNot(Offset.zero));
    });

    test('initialPositions reduces temperature', () {
      final full = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
      );
      final incremental = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
        initialPositions: [
          const Offset(100, 100),
          const Offset(200, 200),
          const Offset(300, 300),
          null, // one new node
        ],
      );

      // Incremental layout should settle faster (lower starting temperature)
      var fullSteps = 0;
      while (full.step()) {
        fullSteps++;
      }
      var incrSteps = 0;
      while (incremental.step()) {
        incrSteps++;
      }
      expect(incrSteps, lessThan(fullSteps));
    });

    test('initialPositions null behaves like no argument', () {
      final withNull = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
        initialPositions: null,
      );
      final without = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
      );

      // Same initial positions
      for (var i = 0; i < 3; i++) {
        expect(withNull.positions[i], without.positions[i]);
      }
    });

    group('Dynamic pinning', () {
      test('pinNode freezes node in place during simulation', () {
        final layout = ForceDirectedLayout(
          nodeCount: 3,
          edges: [(0, 1), (1, 2)],
          seed: 42,
        );

        // Run a few steps so nodes spread out
        for (var i = 0; i < 10; i++) {
          layout.step();
        }

        final positionBefore = layout.positions[1];
        layout.pinNode(1);

        // Run more steps — pinned node should not move
        for (var i = 0; i < 20; i++) {
          layout.step();
        }

        expect(layout.positions[1], positionBefore);
      });

      test('unpinNode allows node to resume physics', () {
        final layout = ForceDirectedLayout(
          nodeCount: 3,
          edges: [(0, 1), (1, 2)],
          seed: 42,
        );

        // Settle a bit, then pin/unpin node 1
        for (var i = 0; i < 10; i++) {
          layout.step();
        }

        layout.pinNode(1);
        final pinnedPos = layout.positions[1];

        // Unpin and reheat so it can move
        layout.unpinNode(1);
        layout.reheat();

        // Run to settled — node should have moved from its pinned position
        var steps = 0;
        while (layout.step()) {
          steps++;
          if (steps > 500) break;
        }

        final displacement = (layout.positions[1] - pinnedPos).distance;
        expect(displacement, greaterThan(0.1));
      });

      test('setNodePosition moves a node immediately', () {
        final layout = ForceDirectedLayout(
          nodeCount: 3,
          edges: [(0, 1), (1, 2)],
          seed: 42,
        );

        const target = Offset(100, 200);
        layout.setNodePosition(1, target);

        expect(layout.positions[1], target);
      });

      test('setNodePosition zeros velocity', () {
        final layout = ForceDirectedLayout(
          nodeCount: 3,
          edges: [(0, 1), (1, 2)],
          seed: 42,
        );

        // Run a few steps to build up velocity
        for (var i = 0; i < 5; i++) {
          layout.step();
        }
        // Verify there's some velocity first
        expect(layout.velocities[1].distance, greaterThan(0));

        layout.setNodePosition(1, const Offset(100, 200));
        expect(layout.velocities[1], Offset.zero);
      });

      test('reheat raises temperature after settling', () {
        final layout = ForceDirectedLayout(
          nodeCount: 3,
          edges: [(0, 1), (1, 2)],
          seed: 42,
        );

        // Run to settled
        while (layout.step()) {}
        expect(layout.isSettled, isTrue);

        layout.reheat();

        expect(layout.isSettled, isFalse);
        expect(layout.temperature, greaterThan(layout.settledThreshold));
      });

      test('reheat with custom fraction controls temperature', () {
        final layout = ForceDirectedLayout(
          nodeCount: 3,
          edges: [(0, 1), (1, 2)],
          seed: 42,
        );

        while (layout.step()) {}

        layout.reheat(0.5);
        final highTemp = layout.temperature;

        // Settle again, then reheat with lower fraction
        while (layout.step()) {}
        layout.reheat(0.1);
        final lowTemp = layout.temperature;

        expect(highTemp, greaterThan(lowTemp));
      });
    });

    test('nodes stay near center with gravity', () {
      final layout = ForceDirectedLayout(
        nodeCount: 5,
        edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
        width: 400,
        height: 300,
        seed: 42,
      );

      while (layout.step()) {}

      // With gravity, nodes should stay reasonably near the center
      const center = Offset(200, 150);
      for (final pos in layout.positions) {
        expect((pos - center).distance, lessThan(400.0));
      }
    });
  });
}
